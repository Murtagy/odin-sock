package main

import "socket"
import "core:c"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:slice"
import "core:strings"
import "core:time"


YES : c.int = 1
YES_SIZE : c.uint = size_of(YES)

INC_BUFFER_SIZE :: (1024 * 16) + 17 // 16 kb + random offset to reduce chance of situations when request size is INC_BUFFER_SIZE times X
MAX_INC_SIZE :: 40 * 1024 * 1024 // 40 mb
POOL_SIZE :: 1

INC_DATA := make(map[os.Handle]incomingData)

incomingData :: struct {
    len : int,
    data: [dynamic]c.char,
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

    no_interest_descriptor_idxs: [dynamic]int
    append(&pfds, pollfd{fd=listener, events=POLLIN})

    for {
        print("\nPoll...")
        poll_count := poll(raw_data(pfds), c.int(len(pfds)), -1);
        print("done\n")
        if poll_count == -1 { println("poll error") }


        for descriptor, d_idx in pfds {
            println("descriptor", descriptor.fd == listener ,descriptor)
            // println("BIN", descriptor.revents & POLLIN, descriptor.revents & POLLIN == POLLIN )

            if descriptor.revents & POLLIN == POLLIN {
                if descriptor.fd == listener {  
                    // listener - ready to read, handle new conn
                    fmt.println("listener ready")

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
                    fmt.println("connection ready")

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

                        incoming_data: incomingData
                        if descriptor.fd in INC_DATA {
                            println("Appending to existing data")
                            incoming_data = INC_DATA[descriptor.fd]
                            // println("\n prev: \n", string(incoming_data.data[:]) , incoming_data.len,  len(incoming_data.data))
                            println("\n prev: \n", incoming_data.len,  len(incoming_data.data))
                        }
                        incoming_data.len += int(n_bytes);
                        // for b in client_data_buffer {append(&incoming_data.data, b)}
                        append(&incoming_data.data, ..client_data_buffer[:])

                        INC_DATA[descriptor.fd] = incoming_data

                        if n_bytes < INC_BUFFER_SIZE {
                            // tmp - send OK
                                // println("\n request: \n", string(incoming_data.data[:incoming_data.len]) , "")
                            response := "HTTP/1.1 200 OK\n"
                                sent := send(descriptor.fd, strings.clone_to_cstring(response, context.temp_allocator), c.int(len(response)), 0)
                                    println ("send", sent)
                                closed := os.close(descriptor.fd)
                                    println("closed", closed)
                                append(&no_interest_descriptor_idxs, d_idx)
                            }
                        else {
                            println("__Partial_read__")
                            // expecting more data to come
                        }
                        println(time.diff(t1, time.now()))
                    }
                }
            }
        }

        // drop connections 
        slice.reverse_sort(no_interest_descriptor_idxs[:])
        for d_idx in no_interest_descriptor_idxs{
            println("popping", d_idx)
            fd := pfds[d_idx]
            ordered_remove(&pfds, d_idx)
            delete_key(&INC_DATA, fd.fd)
            println("no longer interested...", d_idx, fd)
        }
        no_interest_descriptor_idxs = {}
        println("clients left", len(pfds)-1)
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