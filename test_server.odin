package main

import "socket"
import "core:c"
import "core:fmt"
import "core:os"


main :: proc() {
	using socket

	serv_addr: sockaddr_in

	listenfd := socket(AddrFamily.INET, SocketType.STREAM, 6)
	fmt.println(" socket: ", listenfd)

	serv_addr.family = AddrFamily.INET
	serv_addr.addr.addr =  htonl(0)
	serv_addr.port = htons(8080)

	fmt.println(
		" bind",
		bind(listenfd, &serv_addr, size_of(serv_addr))
	)
	

	fmt.println(
		" listen",
		listen(listenfd, 10)
	)

	for {
		fmt.println("waiting...")
		connfd := accept(listenfd, nil, 0)
		fmt.println(
			" conndf",
			connfd
		)

		os.write_string(cast(os.Handle)connfd, "Hello, sailor!\n")

		os.close(cast(os.Handle) connfd)
		break
	}
}
