package main

import "socket"
import "core:c"
import "core:fmt"
import "core:os"


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

    poll_count := poll(raw_data(pfds), c.int(len(pfds)), -1)
    if poll_count == -1 {
        println("poll error")
    }

    client_data_buffer : [256]c.char;

    for descriptor in pfds {
        println("descriptor" ,descriptor)
        // println("fd", descriptor.fd)   // this fails
        // println("events", descriptor.events)
        // println("revents", descriptor.revents)
        // println("BIN", descriptor.revents & POLLIN, descriptor.revents & POLLIN == POLLIN )

        if descriptor.revents & POLLIN == POLLIN {
            if descriptor.fd == listener {  // listener is ready to read, handle new conn
                connection := accept(listener, (^sockaddr)(&client_address), addrlen)
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
                nbytes := recv(descriptor.fd , raw_data(&client_data_buffer), size_of(client_data_buffer), 0)
                fmt.println("bytes received", nbytes)
            }
        }
    }

    // connfd := accept(listener, nil, 0)
    // println(
    //     " conndf",
    //     connfd,
    // )

    // os.write_string(cast(os.Handle)connfd, "Hello, sailor!\n")
    // os.close(cast(os.Handle) connfd)
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