package main

import "socket"
import "core:c"
import "core:fmt"
import "core:intrinsics"
import "core:mem"
import "core:os"
import "core:slice"
import "core:strings"
import "core:thread"
import "core:time"


YES : c.int = 1
YES_SIZE : c.uint = size_of(YES)

INC_BUFFER_SIZE :: (1024 * 16) + 17 // 16 kb + random offset to reduce chance of situations when request size is INC_BUFFER_SIZE times X
MAX_INC_SIZE :: 40 * 1024 * 1024 // 40 mb
POOL_SIZE :: 1

REQUESTS_DATA := make(map[os.Handle]Request)  // thread-shared resource, access should be guarded by mutex
REQUESTS_DATA_mutex := b64(false)
no_interest_descriptor_idxs: [dynamic]int  // TODO - guard with mutex !!

Request :: struct {
    data: [dynamic]c.char,
    len : int,
    finished: bool,
}

did_acquire :: proc(m: ^b64) -> (acquired: bool) {
    res, ok := intrinsics.atomic_compare_exchange_strong(m, false, true)
    return ok && res == false
}



pfds: [dynamic]socket.pollfd

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

    append(&pfds, pollfd{fd=listener, events=POLLIN})

    // pool := make_pool()
    pool: thread.Pool
    thread.pool_init(pool=&pool, thread_count=POOL_SIZE, allocator=context.allocator)
    thread.pool_start(&pool)
    defer thread.pool_destroy(&pool)

    for {
        print("\nPoll...")
        poll_count := poll(raw_data(pfds), c.int(len(pfds)), -1);
        print("done\n")
        if poll_count == -1 { println("poll error") }


        for descriptor, d_idx in pfds {
            // println("descriptor", descriptor.fd == listener ,descriptor)
            // println("BIN", descriptor.revents & POLLIN, descriptor.revents & POLLIN == POLLIN )

            if descriptor.revents & POLLIN == POLLIN {
                if descriptor.fd == listener {  
                    // listener - ready to read, handle new conn
                    // fmt.println("listener ready")

                    connection := accept(listener, (^sockaddr)(&client_address), &addrlen)
                    if connection == -1 {
                        fmt.println("Connection failed")
                    }
                    else {
                        append(&pfds, pollfd{fd=connection, events=POLLIN})
                            println("connection fd", connection) // todo: print inet_ntop details
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
                        // schedule remove the conection
                        append(&no_interest_descriptor_idxs, d_idx)
                    }
                    else {
                        t1 := time.now()
                        // fmt.println("bytes received", n_bytes , "from", descriptor.fd)
                        // fmt.println("request: \n\n", string(client_data_buffer[:n_bytes]), "\n")

                        incoming_data: Request
                        {
                            for did_acquire(&REQUESTS_DATA_mutex) {thread.yield()}
                            defer {REQUESTS_DATA_mutex=false}

                            fd, ok := REQUESTS_DATA[descriptor.fd]
                            if ok && fd.finished != true{
                                println("Appending to existing data")
                                println(fd)
                                incoming_data = REQUESTS_DATA[descriptor.fd]
                                // println("\n prev: \n", string(incoming_data.data[:]) , incoming_data.len,  len(incoming_data.data))
                                println("\n prev: \n", incoming_data.len,  len(incoming_data.data))
                            }
                            incoming_data.len += int(n_bytes);
                            // for b in client_data_buffer {append(&incoming_data.data, b)}
                            append(&incoming_data.data, ..client_data_buffer[:])

                            REQUESTS_DATA[descriptor.fd] = incoming_data
                        }

                        if len(incoming_data.data) > MAX_INC_SIZE {
                                response := "HTTP/1.1 200 OK\n"  // todo: change response
                                sent := send(descriptor.fd, strings.clone_to_cstring(response, context.temp_allocator), c.int(len(response)), 0)
                                closed := os.close(descriptor.fd)
                                append(&no_interest_descriptor_idxs, d_idx)
                        } else {
                            if n_bytes < INC_BUFFER_SIZE {
                                println("Full read")
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
        {
            for did_acquire(&REQUESTS_DATA_mutex) {thread.yield()}
            defer {REQUESTS_DATA_mutex=false}

            for descriptor, request in REQUESTS_DATA {
                if request.finished { 
                    for pollfd, idx in pfds {
                        if descriptor == pollfd.fd {
                            append(&no_interest_descriptor_idxs, idx)
                            println("sent response to ", pollfd.fd, "dropping it", idx)
                            break  // if we put no break we have a chance to drop a new connection which has same desriptor
                        }
                    }
                }
            }

            slice.reverse_sort(no_interest_descriptor_idxs[:])
            for d_idx in no_interest_descriptor_idxs{
                println("popping", d_idx)
                fd := pfds[d_idx]
                ordered_remove(&pfds, d_idx)
                delete_key(&REQUESTS_DATA, fd.fd)
                // closed := os.close(fd.fd)
                println("no longer interested...", d_idx, fd)  //"closed", closed)
            }
            no_interest_descriptor_idxs = {}
            println("clients left", len(pfds)-1)


        }
    }
}


make_pool :: proc() -> thread.Pool {
    pool: thread.Pool
    thread.pool_init(pool=&pool, thread_count=POOL_SIZE, allocator=context.allocator)
    thread.pool_start(&pool)
    return pool
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
        // fmt.println("1")
        // todo: see sync.guard
        for did_acquire(&REQUESTS_DATA_mutex) {thread.yield()}
        defer {REQUESTS_DATA_mutex=false}
        // fmt.println("2")

        request := REQUESTS_DATA[request_descriptor]
        request_text = string(request.data[:])
    }


    response := handle_ping(request_text)
    c_response := strings.clone_to_cstring(response, context.temp_allocator)
    sent := socket.send(request_descriptor, c_response, c.int(len(c_response)), 0)
    fmt.println("sent", sent)
    // fmt.println("2.5")
    // append(&no_interest_descriptor_idxs, pfds_idx)
    {
        // fmt.println("3")
        for did_acquire(&REQUESTS_DATA_mutex) {thread.yield()}
        defer {REQUESTS_DATA_mutex=false}
        // fmt.println("4")

        request.finished = true
        REQUESTS_DATA[request_descriptor] = request
    }
    closed := os.close(request_descriptor)

    fmt.println("Finishing task")
}


handle_ping :: proc(request: string) -> (response: string) {
    fmt.println("PING!!")
    return "HTTP/1.1 200 OK\n"
}


