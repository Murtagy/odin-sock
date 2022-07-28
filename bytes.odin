package main

import "core:c"
import "core:fmt"


main :: proc() {
    fmt.println("uchar", size_of(c.uchar))
    fmt.println("ushort", size_of(c.ushort))
    fmt.println("uint", size_of(c.uint))
    fmt.println("int", size_of(c.int))
    fmt.println("byte", size_of(byte))
    fmt.println("char", size_of(c.char))

}
