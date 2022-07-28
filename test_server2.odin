package main

import "socket"
import "core:c"
import "core:fmt"
import "core:os"


main :: proc() {
	using socket


    port: cstring = "8080"
    hints : addrinfo
    serv_addr: ^addrinfo

    hints.flags = addrinfoFlags.AI_PASSIVE
    hints.family = c.int(AF_UNSPEC)
    hints.socktype = SocketType.STREAM

    fmt.println(
        "getaddrinfo",
        getaddrinfo(nil, port, &hints, &serv_addr)
    )
	listener := socket(serv_addr.family, serv_addr.socktype, serv_addr.protocol)	

	// trying to bind to first, note that systematic bind should iterate next until exhausted
	fmt.println(
		" bind",
		bind(listener,  serv_addr.addr, serv_addr.addrlen)
	)
	// fmt.println("!!!", serv_addr.addrlen, size_of(addr))

	fmt.println(
		" listen",
		listen(listener, 10)
	)

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
