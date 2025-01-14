package main

import "socket"
import "core:c"
import "core:fmt"
import "core:os"



main :: proc() {
	using socket


	// manual way
	listener := socket(c.int(AF_INET), SocketType.STREAM, 6)
	fmt.println(" socket: ", listener)

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

	for {
		fmt.println("waiting...")
		connfd := accept(listener, nil, &zero_length)
		fmt.println(
			" conndf",
			connfd
		)

		os.write_string(cast(os.Handle)connfd, "Hello, sailor!\n")

		os.close(cast(os.Handle) connfd)
		break
	}
}
