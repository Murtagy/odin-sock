package main

import "socket"
import "core:c"
import "core:fmt"
import "core:os"


main :: proc() {
	using socket

	serv_addr: SockAddr_in

	listenfd := socket(AddrFamily.INET, Type.STREAM, 0)

	serv_addr.family = cast(c.uchar) AddrFamily.INET
	serv_addr.addr.addr = cast(c.uint) htonl(0)
	serv_addr.port = htons(8080)

	bind(listenfd, &serv_addr, size_of(serv_addr))
	fmt.println(serv_addr)

	listen(listenfd, 10)

	for {
		connfd := accept(listenfd, nil, 0)

		os.write_string(cast(os.Handle)connfd, "Hello, sailor!\n")

		os.close(cast(os.Handle) connfd)
	}
}
