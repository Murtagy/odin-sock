package main

import "core:fmt"

S :: struct {a: int, dyn: [dynamic]int}


main :: proc() {
    using fmt

    a := S{}
    append(&a.dyn, 9)
    b := a

    // a.a = 5
    // b.a = 3

    b.dyn = clone_dynamic_array(a.dyn)

    // println("a.a", a.a)  // a.a = 5
    // println("b.a", b.a)  // b.a = 3

    append(&a.dyn, 1)
    append(&b.dyn, 2)

    println("a.dyn", a.dyn)
    println("b.dyn", b.dyn)

}

clone_dynamic_array :: proc(x: $T/[dynamic]$E) -> T {
    res := make(T, len(x));
    copy(res[:], x[:]);
    return res;
}