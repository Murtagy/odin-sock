package main

import "socket"
import "core:c"
import "core:fmt"
import "core:intrinsics"
import "core:mem"
import "core:os"
import "core:slice"
import "core:strings"
import "core:sync"
import "core:thread"
import "core:time"


YES : c.int = 1
YES_SIZE : c.uint = size_of(YES)

INC_BUFFER_SIZE :: (1024 * 16) + 17 // 16 kb + random offset to reduce chance of situations when request size is INC_BUFFER_SIZE times X
MAX_INC_SIZE :: 40 * 1024 * 1024 // 40 mb
POOL_SIZE :: 1
MAX_CONNECTIONS :: 1024


REQUESTS_DATA := make(map[os.Handle]Request)  // thread-shared resource, access should be guarded by mutex
// REQUESTS_DATA_mutex := b64(false)
REQUESTS_DATA_mutex : sync.Mutex
no_interest_descriptor_idxs: [dynamic]int  // TODO - guard with mutex !!

Request :: struct {
    len : int,
    responsed: bool,
    pfds_index: int,
    data: [dynamic]c.char,
}

did_acquire :: proc(m: ^b64) -> (acquired: bool) {
    res, ok := intrinsics.atomic_compare_exchange_strong(m, false, true)
    return ok && res == false
}

pfds_T :: [MAX_CONNECTIONS]socket.pollfd

listener_n :: 1
current_connections : int


add_to_pfds :: proc(pfds: ^pfds_T, new: os.Handle, current_last_index: ^int) {
    using socket

    current_last_index^ += 1
    pfds[current_last_index^] = pollfd{fd=new, events=POLLIN}
}

del_from_pfds :: proc (pfds: ^pfds_T, del_index: int, current_last_index: ^int) {
    pfds[del_index] = pfds[current_last_index^]
    current_last_index^ -= 1
}


main :: proc() {
    using fmt
	using socket
    addrlen : c.uint = size_of(socklen_t)


    listener := get_listener_socket()
    if listener == -1 {
        println("error getting listening socket")
    }

    client_address: sockaddr_storage
    client_data_buffer : [INC_BUFFER_SIZE]c.char;

    pool: thread.Pool
    thread.pool_init(pool=&pool, thread_count=POOL_SIZE, allocator=context.allocator)
    thread.pool_start(&pool)
    defer thread.pool_destroy(&pool)

    pfds: pfds_T
    pfds[0] = pollfd{fd=listener, events=POLLIN}

    for {
        print("\nPoll...")
        poll_count := poll(raw_data(&pfds), c.int(current_connections + listener_n), -1); print("done\n")
        if poll_count == -1 { println("poll error") }

        { sync.guard(&REQUESTS_DATA_mutex)
            for descriptor, d_idx in pfds {
                if descriptor.revents & POLLIN == POLLIN {
                    if descriptor.fd == listener {  
                        connection_fd := accept(listener, (^sockaddr)(&client_address), &addrlen)
                        if connection_fd == -1 { 
                            println("Connection failed")
                        }
                        else {
                            request : Request = {pfds_index=d_idx}
                            REQUESTS_DATA[connection_fd] = request
                            add_to_pfds(&pfds, connection_fd, &current_connections)
                            println(pfds[:5])
                            println("connection fd", connection_fd) // todo: print inet_ntop details

                        }
                    }
                    else {
                        // client - let's receive some bytes from it
                        fmt.println("connection sent some data", descriptor)

                        n_bytes := recv(descriptor.fd , raw_data(&client_data_buffer), size_of(client_data_buffer), 0)
                        if n_bytes <= 0 {  // err or closed
                            if n_bytes == 0 {
                                println(descriptor.fd, "disconnected")
                            }
                            else {
                                println("recv error")
                            }
                            append(&no_interest_descriptor_idxs, d_idx)

                        }
                        else {
                            t1 := time.now()

                            incoming_data := REQUESTS_DATA[descriptor.fd]
                            incoming_data.len += int(n_bytes);
                            append(&incoming_data.data, ..client_data_buffer[:])
                            REQUESTS_DATA[descriptor.fd] = incoming_data

                            if len(incoming_data.data) > MAX_INC_SIZE {
                                // for too big responses we don't pass it to thread pool so far
                                fd := descriptor.fd
                                response := "Request too big \n"  // todo: handle better
                                sent := send(fd, strings.clone_to_cstring(response, context.temp_allocator), c.int(len(response)), 0)
                                delete_key(&REQUESTS_DATA, descriptor.fd)
                                del_from_pfds(&pfds, d_idx, &current_connections)
                                os.close(descriptor.fd)
                            } else {
                                if n_bytes < INC_BUFFER_SIZE {
                                    println("Full read")
                                    del_from_pfds(&pfds, d_idx, &current_connections)
                                    thread.pool_add_task(
                                        pool=&pool,
                                        procedure=handle_full_populated_request_task,
                                        data=nil, //&descriptor.fd,
                                        user_index=int(descriptor.fd),
                                        allocator=context.allocator,
                                    )
                                }
                                else {
                                    println("__Partial_read__")
                                    // expecting more data to come
                                }
                            }
                            println(time.diff(t1, time.now()))
                        }
                    }
                }
            }

            // drop connections 
            for descriptor, request in REQUESTS_DATA {
                if request.responsed { 
                    delete_key(&REQUESTS_DATA, descriptor)
                    os.close(descriptor)
                }
            }
        }
    }
}


get_listener_socket :: proc() -> os.Handle {
    using socket

	listener := socket(c.int(AF_INET), SocketType.STREAM, 6)
	fmt.println(" listener socket: ", listener)

    fmt.println(
        "setsockopt",
        setsockopt(listener, SOL_SOCKET, SO_REUSEADDR, &YES, YES_SIZE),
    )

    fmt.println(
        "getsockopt",
        getsockopt(listener, SOL_SOCKET, SO_REUSEADDR, &YES, &YES_SIZE),
    )
	serv_addr: sockaddr_in
	serv_addr.family = AF_INET
	serv_addr.addr.addr =  htonl(0)
	serv_addr.port = htons(8080)
    fmt.println(serv_addr)
	fmt.println((^sockaddr)(&serv_addr) , "SIZE", size_of((^sockaddr)(&serv_addr)))

	fmt.println(
		" bind",
		bind(listener, (^sockaddr)(&serv_addr), size_of(serv_addr)),
	)
	

	fmt.println(
		" listen",
		listen(listener, 10),
	)
    return listener
}

handle_full_populated_request_task :: proc(t: thread.Task) {
    // descriptor :os.Handle = (^os.Handle)(t.data)^;
    fmt.println("TRYING TO HANDLE A REQUEST TASK!")
    request_descriptor := os.Handle(t.user_index)
    fmt.println("request_descriptor", request_descriptor)

    request: Request
    request_text : string
    {
        sync.guard(&REQUESTS_DATA_mutex)
        request := REQUESTS_DATA[request_descriptor]
    }
    request_text = string(request.data[:])

    response := handle_ping(request_text)
    c_response := strings.clone_to_cstring(response, context.temp_allocator)
    fmt.println("response", c_response)
    sent := socket.send(request_descriptor, c_response, c.int(len(c_response)), 0)
    fmt.println("sent", sent)

    {
        sync.guard(&REQUESTS_DATA_mutex)

        os.close(request_descriptor)
        delete_key(&REQUESTS_DATA, request_descriptor)
    }

    fmt.println("Finishing task")
}


handle_ping :: proc(request: string) -> (response: string) {
    fmt.println(request)
    fmt.println("PING!!")
    return "HTTP/1.1 200 OK\n"
}

// multi syncs
// Requests per second:    60.66 [#/sec] (mean)

// less syncs
// Requests per second:    49.21 [#/sec] (mean)