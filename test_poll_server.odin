package main

import "socket"
import "core:c"
import "core:fmt"
import "core:intrinsics"
import "core:log"
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
POOL_SIZE :: 2
MAX_CONNECTIONS :: 8


REQUESTS_DATA := make(map[os.Handle]Request)  // thread-shared resource, access should be guarded by mutex
REQUESTS_DATA_mutex : sync.Mutex

Request :: struct {
    len : int,
    responsed: bool,
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
    log.debug("Added", new, "at index", current_last_index^)
}

del_from_pfds :: proc (pfds: ^pfds_T, del_index: int, current_last_index: ^int, loop_index: ^int) {
    loop_index^ -= 1  // lower the index to revisit (if needed) the element which is now placed under del_index

    if del_index != current_last_index^ {
        pfds[del_index] = pfds[current_last_index^]
        log.debug("Placed", current_last_index^, "at index", del_index, ". Loop index", loop_index^)
    }

    current_last_index^ -= 1 
}


main :: proc() {
    using fmt
	using socket

    context.logger = log.create_console_logger()

    addrlen : c.uint = size_of(socklen_t)


    listener := get_listener_socket()
    if listener == -1 {
        log.error("error getting listening socket")
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
        log.info("\nPoll...", c.int(current_connections + listener_n), pfds[:current_connections + listener_n + 2])
        poll_count := poll(raw_data(&pfds), c.int(current_connections + listener_n), -1)
        log.debug("poll_done\n")
        if poll_count == -1 { log.panic("poll error") }

        { sync.guard(&REQUESTS_DATA_mutex)
            for d_idx := 0; d_idx < (current_connections + listener_n); d_idx += 1 {
                descriptor := pfds[d_idx]

                if descriptor.revents & POLLIN == POLLIN {
                    con := descriptor.fd

                    if con == listener {  
                        connection_fd := accept(listener, (^sockaddr)(&client_address), &addrlen)
                        if connection_fd == -1 { 
                            log.panic("Connection failed")
                        }
                        else {
                            request : Request = {}
                            REQUESTS_DATA[connection_fd] = request
                            add_to_pfds(&pfds, connection_fd, &current_connections)
                            log.debug("connection fd", connection_fd) // todo: print inet_ntop details

                        }
                    }
                    else {
                        // client - let's receive some bytes from it
                        log.debug("connection sent some data", descriptor)

                        n_bytes := recv(con , raw_data(&client_data_buffer), size_of(client_data_buffer), 0)
                        if n_bytes <= 0 {  // err or closed
                            if n_bytes == 0 {
                                log.debug(con, "disconnected")
                            }
                            else {
                                log.debug("recv error")
                            }
                            del_from_pfds(&pfds, d_idx, &current_connections, &d_idx)
                            delete_key(&REQUESTS_DATA, con)
                            closed := os.close(con)
                            if closed == false {log.panic("CLOSED")}
                        }
                        else {
                            t1 := time.now()

                            incoming_data := REQUESTS_DATA[con]
                            incoming_data.len += int(n_bytes);
                            append(&incoming_data.data, ..client_data_buffer[:])
                            REQUESTS_DATA[con] = incoming_data

                            if len(incoming_data.data) > MAX_INC_SIZE {
                                // for too big responses we don't pass it to thread pool so far
                                response := "Request too big \n"  // todo: handle better
                                sent := send(con, strings.clone_to_cstring(response, context.temp_allocator), c.int(len(response)), 0)
                                del_from_pfds(&pfds, d_idx, &current_connections, &d_idx)
                                delete_key(&REQUESTS_DATA, con)
                                closed := os.close(con)

                                if closed == false {log.panic("CLOSED")}
                                log.panic("BIG")
                            } else {
                                if n_bytes < INC_BUFFER_SIZE {
                                    log.debug("Full read")
                                    del_from_pfds(&pfds, d_idx, &current_connections,  &d_idx)
                                    // handle_full_populated_request_task(con)
                                    thread.pool_add_task(
                                        pool=&pool,
                                        procedure=handle_full_populated_request_task,
                                        data=nil, //&descriptor.fd,
                                        user_index=int(con),
                                        allocator=context.allocator,
                                    )
                                }
                                else {
                                    log.warn("__Partial_read__")
                                    // expecting more data to come
                                }
                            }
                            log.debug("time", time.diff(t1, time.now()))
                            time.sleep(1 * time.Millisecond)  // for some crazy reason server freezes at 16339 +- 50 requests
                        }
                    }
                }
            }
        }
    }
}


get_listener_socket :: proc() -> os.Handle {
    using socket

	listener := socket(c.int(AF_INET), SocketType.STREAM, 6)
	log.debug(" listener socket: ", listener)

    log.debug(
        "setsockopt",
        setsockopt(listener, SOL_SOCKET, SO_REUSEADDR, &YES, YES_SIZE),
    )

    log.debug(
        "getsockopt",
        getsockopt(listener, SOL_SOCKET, SO_REUSEADDR, &YES, &YES_SIZE),
    )
	serv_addr: sockaddr_in
	serv_addr.family = AF_INET
	serv_addr.addr.addr =  htonl(0)
	serv_addr.port = htons(8080)
    log.debug(serv_addr)
	log.debug((^sockaddr)(&serv_addr) , "SIZE", size_of((^sockaddr)(&serv_addr)))

	log.debug(
		" bind",
		bind(listener, (^sockaddr)(&serv_addr), size_of(serv_addr)),
	)
	

	log.debug(
		" listen",
		listen(listener, 10),
	)
    return listener
}


handle_full_populated_request_task :: proc(t: thread.Task) {
    // descriptor :os.Handle = (^os.Handle)(t.data)^;
    log.debug("TRYING TO HANDLE A REQUEST TASK!", t.user_index)
    request_descriptor := os.Handle(t.user_index)

    request: Request
    request_text : string
    {
        sync.guard(&REQUESTS_DATA_mutex)
        request := REQUESTS_DATA[request_descriptor]
    }
    request_text = string(request.data[:])

    response := handle_ping(request_text)
    c_response := strings.clone_to_cstring(response, context.temp_allocator)
    // fmt.println("response", c_response)
    sent := socket.send(request_descriptor, c_response, c.int(len(c_response)), 0)
    log.debug("response sent: ", sent)

    {
        sync.guard(&REQUESTS_DATA_mutex)

        closed := os.close(request_descriptor)
        if closed == false {log.panic("CLOSED")}
        delete_key(&REQUESTS_DATA, request_descriptor)
    }

    log.debug("Finishing task")
}


handle_ping :: proc(request: string) -> (response: string) {
    // fmt.println(request)
    log.debug("PING!!")
    return "HTTP/1.1 200 OK\n"
}

// multi syncs
// Requests per second:    60.66 [#/sec] (mean)

// less syncs
// Requests per second:    49.21 [#/sec] (mean)