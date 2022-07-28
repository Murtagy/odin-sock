package main

import "socket"
import "core:c"
import "core:fmt"
import "core:os"


YES : c.int = 1
YES_SIZE :: size_of(YES)

pfds: [dynamic]socket.pollfd

main :: proc() {
	using socket

	// manual way
    listener := get_listener_socket()


	for {
		fmt.println("waiting...")
		connfd := accept(listener, nil, 0)
		fmt.println(
			" conndf",
			connfd
		)

		os.write_string(cast(os.Handle)connfd, "Hello, sailor!\n")

		os.close(cast(os.Handle) connfd)
		break
	}
}


get_listener_socket :: proc() -> os.Handle {
    using socket

	listener := socket(c.int(AF_INET), SocketType.STREAM, 6)
	fmt.println(" socket: ", listener)

    fmt.println(
        "setsockopt",
        setsockopt(listener, SOL_SOCKET, SO_REUSEADDR, &YES, YES_SIZE)
    )

	serv_addr: sockaddr_in
	serv_addr.family = AF_INET
	serv_addr.addr.addr =  htonl(0)
	serv_addr.port = htons(8080)
    fmt.println(serv_addr)
	fmt.println((^sockaddr)(&serv_addr) , "SIZE", size_of((^sockaddr)(&serv_addr)))

	fmt.println(
		" bind",
		bind(listener, (^sockaddr)(&serv_addr), size_of(serv_addr))
	)
	

	fmt.println(
		" listen",
		listen(listener, 10)
	)
    return listener
}