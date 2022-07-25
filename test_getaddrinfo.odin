package main

import "socket"
import "core:c"
import "core:fmt"
import "core:os"

main :: proc() {
    using socket

    node: cstring = "www.example.net"
    service: cstring = "80"
    hints : Addrinfo
    server_info: ^Addrinfo

    hints.family = AddrFamily.UNSPEC
    hints.socktype = Type.STREAM

    fmt.println(
        getaddrinfo(node, service, &hints, &server_info)
    )

}