package main

import "socket"
import "core:c"
import "core:fmt"
import "core:os"


main :: proc() {
    using socket

    stdin := pollfd{fd=0, events=POLLIN}
    pfds: [dynamic]pollfd
    append(&pfds, stdin)
    fmt.println("Hit RETURN or wait 2.5 seconds for timeout")
    num_events := poll(raw_dynamic_array_data(pfds), c.int(1), c.int(2500))
    fmt.println(num_events)



}