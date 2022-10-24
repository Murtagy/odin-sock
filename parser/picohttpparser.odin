package parser

import "core:fmt"
import "core:c"
import "core:strings"
import "core:mem"



phr_header :: struct {
    name: cstring,
    name_len: size_t,
    value: cstring,
    value_len: size_t,
}


when ODIN_OS == .Windows do foreign import picohttpparser "picohttpparser.lib"
when ODIN_OS == .Linux   do foreign import picohttpparser "picohttpparser.a"
when ODIN_OS == .Darwin  do foreign import picohttpparser "picohttpparser.o"

size_t :: c.ulong


foreign picohttpparser {
    phr_parse_request   :: proc(buf: cstring, len: size_t, method: ^cstring, method_len: ^size_t, path: ^cstring, path_len: ^size_t, minor_version: ^c.int, headers: ^phr_header, num_headers: ^size_t, last_len: size_t)    -> c.int ---
}



MAX_HEADERS :: 100
MAX_HEADERS_int : size_t = MAX_HEADERS

HttpRequest :: struct {
    raw : [dynamic]c.char,

    method        : cstring           ,
    method_len    : size_t            ,
    path          : cstring           ,
    path_len      : size_t            ,
    headers       : [MAX_HEADERS]phr_header   ,
    num_headers   : size_t            ,
    minor_version : c.int             ,
}

parse_request :: proc(pre_request: ^HttpRequest) -> bool {
    using pre_request
    // fmt.println("raw", raw)
    cstr := strings.clone_to_cstring(string(pre_request.raw[:]), context.allocator) // temp_allocator?
    // fmt.println("PARSE")
    // fmt.println(pre_request.num_headers, MAX_HEADERS_int)

    err := phr_parse_request(
        cstr,
        size_t(len(cstr)),
        &method,
        &method_len,
        &path,
        &path_len,
        &minor_version,
        raw_data(&headers),
        &MAX_HEADERS_int,
        size_t(0),
    )
    fmt.println("PARSE EXIT")
    return err != -1
}


// test purposes
PARSE :: proc(s: string, last_len: int, exp: int, comment: string) -> bool {
    
    slen := size_of(s) -1
    method : cstring
    method_len : size_t
    path : cstring
    path_len : size_t
    minor_version: c.int
    headers : [4]phr_header
    num_headers: size_t = 4

    cs := strings.clone_to_cstring(s, context.temp_allocator)

    err := phr_parse_request(
        cs,
        size_t(len(cs)),
        &method,
        &method_len,
        &path,
        &path_len,
        &minor_version,
        raw_data(&headers),
        &num_headers,
        size_t(last_len),
    )
    // fmt.println(
    //     "full:\n", cs,
    //     "size:", size_t(size_of(cs)),
    //     "len:", size_t(len(cs)),
    //     "mylen:", len(cs), "\n",
    //     "mylen:", len(s), "\n",
    //     "method: ", string(method)[:method_len], "\n",
    //     "path: ", string(path)[:path_len],  "\n",
    //     "minor", minor_version,
    //     headers,
    //     "num_headers", num_headers, "\n",
    //     size_t(last_len),
    // )
    return err != -1
}

main :: proc() {
    res: bool
    
    // TODO: copy asserts from test.c

    res = PARSE("GET / HTTP/1.0\r\n\r\n", 0, 0, "simple")
    fmt.println("1", res)

    res = PARSE("GET /hoge HTTP/1.1\r\nHost: example.com\r\nCookie: \r\n\r\n", 0, 0, "parse headers");
    fmt.println("2", res)

    res = PARSE("GET /hoge HTTP/1.1\r\nHost: example.com\r\nUser-Agent: \343\201\262\343/1.0\r\n\r\n", 0, 0, "multibyte included");
    fmt.println("3", res)


}