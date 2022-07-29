package main

import "core:c"
import "core:fmt"
import "socket"
import "core:os"


main :: proc() {
    fmt.println("uchar", size_of(c.uchar))
    fmt.println("ushort", size_of(c.ushort))
    fmt.println("short", size_of(c.short))
    fmt.println("uint", size_of(c.uint))
    fmt.println("int", size_of(c.int))
    fmt.println("byte", size_of(byte))
    fmt.println("char", size_of(c.char))
    fmt.println("socket.sockaddr_storage", size_of(socket.sockaddr_storage))
    fmt.println("socket.pollfd", size_of(socket.pollfd))
    // fmt.println("os.Handle", size_of(os.Handle))

}
