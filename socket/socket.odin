package socket

foreign import libc "system:c"
import "core:c"
import "core:os"

/* NOTE(renehsz):
 *  I'm still unsure about whether I should use primitive types or define my
 *  own destinct ones. E.g.: socklen_t, ...
 *  Also I'm partially not sure whether to put the C defines in enums or in
 *  constants (currently there's both, which is stupid).
 *  External feedback is highly appreciated.
 */

zero_length :c.uint = 0
C_Errno :: c.int
// Communication Domain/Address Family
ADDRESS_FAMILY :: c.ushort
AF_UNSPEC : c.ushort : 0
AF_INET : c.ushort : 2

sockaddr :: struct {
    family: ADDRESS_FAMILY, // address family, xxx
    data:   [14]byte, // 14 bytes of protocol address
}

sockaddr_in :: struct {  // Socket address, internet style.
    family: ADDRESS_FAMILY,
    port:   c.ushort,
    addr:   InAddr,
    zero:   [8]byte,
}

sockaddr_storage :: struct { // 128 bytes
    // ss_len
    ss_family: ADDRESS_FAMILY,
    __ss_pad1: [6]c.char,
    __ss_align: i64,
    __ss_pad2: [112]c.char,
}
InAddr :: struct {  // Internet address (a structure for historical reasons)
    addr: c.uint,  // __uint32_t
}

addrinfoFlags :: enum c.int {
    NOT_SET        = 0,
    AI_PASSIVE     = 0x00000001, // Socket address is intended for bind.
}
SocketType :: enum c.int {
    STREAM    = 1,  // stream (connection) socket
    DGRAM     = 2,  // datagram (conn.less) socket
    RAW       = 3,  // raw socket
    RDM       = 4,  // reliably-delivered message
    SEQPACKET = 5,  // sequential packet socket
    PACKET    = 10, /* linux specific way of
                     * getting packets at the device
                     * level.  For writing rarp and
                     * other similar things at the
                     * user level. Obsolete.       */
}

addrinfo :: struct {
    // ints
    flags:     addrinfoFlags,
    family:    c.int,
    socktype:  SocketType,
    protocol:  c.int,
    // size_t per system
    addrlen:   c.uint32_t,  
    // others
    canonname: cstring,
    addr:      ^sockaddr,
    next:      ^addrinfo,
}

// Error values for getaddrinfo
addrinfoError :: enum c.int {
    SUCCESS        =  0,  // Yay

    // my mac seems to set these differently in netdb.h:

    EAI_BADFLAGS   = -1,  // Invalid value for flags field.
    EAI_NONAME     = -2,  // NAME or SERVICE is unknown.
    EAI_AGAIN      = -3,  // Temporary failure in name resolution.
    EAI_FAIL       = -4,  // Non-recoverable failure in name resolution.
    EAI_NODATA     = -5,  // No address associated with NAME.
    EAI_FAMILY     = -6,  // family not supported.
    EAI_SOCKTYPE   = -7,  // socktype not supported.
    EAI_SERVICE    = -8,  // SERVICE not supported for socktype.
    EAI_ADDRFAMILY = -9,  // Address family for NAME not supported.
    EAI_MEMORY     = -10, // Memory allocation failure.
    EAI_SYSTEM     = -11, // System error returned in errno.
    EAI_OVERFLOW   = -12, // Argument buffer overflow.
}

// NOTE(renehsz): These are apparently GNU extensions... not sure if they are portable
EAI_INPROGRESS  :: -100; // Processing request in progress.
EAI_CANCELED    :: -101; // Request canceled.
EAI_NOTCANCELED :: -102; // Request not canceled.
EAI_ALLDONE     :: -103; // All request done.
EAI_INTR        :: -104; // Interrupted by a signal.
EAI_IDN_ENCODE  :: -105; // IDN encoding failed.

Ifaddrs :: struct {
    next:     ^Ifaddrs,         // Next item in list
    name:     cstring,          // Name of interface
    flags:    c.uint,           // Flags from SIOCGIFFLAGS
    addr:     ^sockaddr,      // Address of interface
    netmask:  ^sockaddr,      // Netmask of interface
    ifu_addr: ^sockaddr,      /* Broadcast address of interface if IFF_BROADCAST is set or
                         * point-to-point destination address if IFF_POINTTOPOINT is set
                         * in flags */
    data:     rawptr,
}

NI_NUMERICHOST :: 1;
NI_NUMERICSERV :: 2;

Hostent :: struct {
    name:      cstring,  // The official name of the host
    aliases:   ^cstring, // An array of alternative names for the host, terminated by a null pointer
    addrtype:  c.int,    // The type of address; always AF_INET or AF_INET6 at present.
    length:    c.int,    // The length of the address in bytes.
    addr_list: ^cstring, // An array of pointers to network addresses for the host (in network byte order), terminated by a null pointer.
}

Protoent :: struct {
    name:    cstring,  // official protocol name
    aliases: ^cstring, // alias list
    proto:   c.int,    // protocol #
}

Serevent :: struct {
    name:    cstring,  // official service name
    aliases: ^cstring, // alias list
    port:    c.int,    // port #
    proto:   cstring,  // protocol to use
}

Netent :: struct {
    name:     cstring,
    aliases:  ^cstring,
    addrtype: c.int,
    net:      c.ulong,
}

Rpcent :: struct {
    name:    cstring,
    aliases: ^cstring,
    proto:   c.int,
}

Linger :: struct {
    onoff:  c.int, // Linger active
    linger: c.int, // How long to linger for
}

Msghdr :: struct {
    name:       rawptr,  // Socket name
    namelen:    c.int,   // Length of name
    iov:        rawptr,  // Data blocks
    iovlen:     c.int,   // Number of blocks
    control:    rawptr,  // Per protocol magic (eg BSD file descriptor passing)
    controllen: c.int,   // Length of rights list
    flags:      c.int,   // 4.4 BSD field we dont use
}

SOMAXCONN :: 128;

pollfd :: struct {          // should be 8 bytes on my machine
        fd:      os.Handle,  // the socket descriptor
        events:  c.short,   // bitmap of events we're interested in
        revents: c.short,   // when poll() returns, bitmap of events that occurred
}

socklen_t :: c.uint32_t

POLLIN :      :        0x0001 
SOL_SOCKET:   :        0xffff 
SO_REUSEADDR: :        0x0004


@(default_calling_convention="c")
foreign libc {
    h_errno: c.int;

    // rubbish       :: proc(i: c.int) ---; // was testing linker

    accept        :: proc(sockfd: os.Handle, addr: ^sockaddr, addrlen: ^c.uint) -> os.Handle ---;
    accept4       :: proc(sockfd: os.Handle, addr: ^sockaddr, addrlen: c.uint, flags: c.int) -> os.Handle ---;
    bind          :: proc(sockfd: os.Handle, addr: ^sockaddr, addrlen: c.uint) -> c.int ---;
    connect       :: proc(sockfd: os.Handle, addr: ^sockaddr_in, addrlen: c.uint) -> c.int ---;
    endhostent    :: proc() ---;
    fcntl         :: proc(s: c.int, cmd: c.int, arg: c.long) -> c.int ---;
    freeifaddrs   :: proc(ifa: Ifaddrs) ---;
    freeaddrinfo  :: proc(res: ^addrinfo) ---;
    gai_strerror  :: proc(res: ^addrinfo) -> cstring ---;
    getaddrinfo   :: proc(node, service: cstring, hints: ^addrinfo, res: ^^addrinfo) -> addrinfoError ---;
    gethostbyname :: proc(name: cstring) -> ^Hostent ---;
    gethostbyaddr :: proc(addr: rawptr, len: c.uint, typ: c.int) -> ^Hostent ---;
    getnameinfo   :: proc(addr: ^sockaddr, addrlen: c.uint, host: cstring, hostlen: c.uint, serv: cstring, servlen: c.uint, flags: c.int) -> c.int ---;
    gethostent    :: proc() -> ^Hostent ---;
    getifaddrs    :: proc(ifap: ^Ifaddrs) -> c.int ---;
    getsockname   :: proc(sockfd: os.Handle, addr: ^sockaddr, addrlen: c.uint) -> c.int ---;
    getsockopt    :: proc(sockect: os.Handle, level: c.int, optname: c.int, optval: ^c.int, socklen: ^c.uint) -> c.int ---;
    herror        :: proc(s: cstring) ---;
    hstrerror     :: proc(err: c.int) -> cstring ---;
    htonl         :: proc(hostlong: u32) -> u32 ---;
    htons         :: proc(hostshort: u16) -> u16 ---;
    listen        :: proc(sockfd: os.Handle, backlog: c.int) -> c.int ---;
    ntohl         :: proc(netlong: u32) -> u32 ---;
    ntohs         :: proc(netshort: u16) -> u16 ---;
    poll          :: proc(fds: ^pollfd, number_of_file_descriptors: c.int, timeout: c.int) -> c.int ---;
    recv          :: proc(socket: os.Handle, buffer: ^byte, len: c.int, flags: c.int) -> c.int ---;
    send          :: proc(socket: os.Handle, msg: cstring, len: c.int, flags: c.int) -> c.int ---;
    sethostent    :: proc(stayopen: c.int) ---;
    setsockopt    :: proc(socket: os.Handle, level: c.int, optname: c.int, optval: ^c.int, socklen: c.uint) -> c.int ---;
    socket        :: proc(domain: c.int, typ: SocketType, protocol: c.int) -> os.Handle ---;

}

HostErrno :: enum c.int {
    HOST_NOT_FOUND = 1,       // Authoritive Answer Host not found
    TRY_AGAIN      = 2,       // Non-Authoritive Host not found, or SERVERFAIL
    NO_RECOVERY    = 3,       // Non recoverable errors, FORMERR, REFUSED, NOTIMP
    NO_DATA        = 4,       // Valid name, no data record of requested type
    NO_ADDRESS     = NO_DATA, // no address, look for MX record
}

// h_errno :: HostErrno; TODO(renehsz): this is a foreign C variable, how do we declare that in Odin?
