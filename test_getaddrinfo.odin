package main

import "socket"
import "core:c"
import "core:fmt"
import "core:os"

main :: proc() {
    using socket

    node: cstring = "www.google.com"
    service: cstring = "80"
    hints : addrinfo
    server_info: ^addrinfo

    // hints.flags = addrinfoFlags.AI_PASSIVE
    hints.family = AddrFamily.UNSPEC
    hints.socktype = SocketType.STREAM

    fmt.println(
        "getaddrinfo",
        getaddrinfo(node, service, &hints, &server_info)
    )
    fmt.println(server_info)

}