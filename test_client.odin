package main

import "socket"
import "core:c"
import "core:fmt"
import "core:os"


main :: proc() {
	using socket

	server_addr: sockaddr_in

	connfd := socket(AddrFamily.INET, SocketType.STREAM, 6)
	fmt.println(" socket: ", connfd)

	server_addr.family = cast(c.uchar) AddrFamily.INET
	server_addr.addr.addr = cast(c.uint) htonl(0)
	server_addr.port = htons(8080)

	fmt.println(
		" connect",
		connect(connfd, &server_addr, size_of(server_addr))
	)

	fmt.println(
		"I am Broot",
		os.write_string(cast(os.Handle)connfd, " I am Broot")
	)

	response : [10240]byte  // 10kb
	len, err := os.read(connfd, response[:1024])  // single read of 1kb

	if err == 1 {
		fmt.println("error")
	}

	fmt.println(
		"response len", len
	)
	fmt.println(
		string(response[:len])
	)
	os.close(connfd)
	
}
