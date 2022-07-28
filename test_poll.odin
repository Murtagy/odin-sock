package main

import "socket"
import "core:c"
import "core:fmt"
import "core:os"


main :: proc() {
    using socket
    pfds := [1]pollfd{}
    pfds[0].fd = 0  // stdin
    pfds[0].events = POLLIN
    fmt.println(size_of(pfds))
    fmt.println(size_of(pfds[:1]))
    fmt.println(size_of(pfds[0]))
    fmt.println("Hit RETURN or wait 2.5 seconds for timeout")
    num_events := poll(raw_data(&pfds), c.int(1), c.int(2500))
    fmt.println(num_events)



}