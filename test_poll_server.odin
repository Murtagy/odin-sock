package main

import "socket"
import "core:c"
import "core:fmt"
import "core:os"
import "core:slice"


YES : c.int = 1
YES_SIZE : c.uint = size_of(YES)

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


    append(&pfds, pollfd{fd=listener, events=POLLIN})



    client_data_buffer : [1_024_000]c.char;

    for {
        print("\nPoll...")
        poll_count := poll(raw_data(pfds), c.int(len(pfds)), -1)
        if poll_count == -1 {
            println("poll error")
        }
        print("done\n")

        no_interest_descriptor_idxs: [dynamic]int

        for descriptor, d_idx in pfds {
            println("descriptor" ,descriptor)
            // println("fd", descriptor.fd)   // this fails
            // println("events", descriptor.events)
            // println("revents", descriptor.revents)
            println("BIN", descriptor.revents & POLLIN, descriptor.revents & POLLIN == POLLIN )

            if descriptor.revents & POLLIN == POLLIN {
                if descriptor.fd == listener {  
                    // listener
                    // ready to read, handle new conn
                    fmt.println("listener ready")
                    connection := accept(listener, (^sockaddr)(&client_address), &addrlen)
                    if connection == -1 {
                        fmt.println("Connection failed")
                    }
                    else {
                        println("connection fd", connection)
                        // todo: print inet_ntop details
                        append(&pfds, pollfd{fd=connection, events=POLLIN})
                    }
                }
                else {
                    // client
                    // let's receive some bytes from it
                    fmt.println("connection ready")
                    nbytes := recv(descriptor.fd , raw_data(&client_data_buffer), size_of(client_data_buffer), 0)
                    if nbytes <= 0 {  // err or closed
                        if nbytes == 0 {
                            println(descriptor.fd, "disconnected")
                        }
                        else {
                            println("recv error")
                        }
                        // schedule remove the conection
                        append(&no_interest_descriptor_idxs, d_idx)
                    }
                    else {
                        fmt.println("bytes received", nbytes , "from", descriptor.fd)
                    }
                }
            }
        }

        slice.reverse_sort(no_interest_descriptor_idxs[:])
        for d_idx in no_interest_descriptor_idxs{
            ordered_remove(&pfds, d_idx)
            println("no longer interested...")
        }
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