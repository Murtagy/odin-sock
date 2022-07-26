#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>

#include <netdb.h>
#include <sys/types.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <arpa/inet.h>

// #define PORT "3490" // the port client will be connecting to 

#define MAXDATASIZE 100 // max number of bytes we can get at once 


void *get_in_addr(struct sockaddr *sa)
{
    if (sa->sa_family == AF_INET) {
        return &(((struct sockaddr_in*)sa)->sin_addr);
    }

    return &(((struct sockaddr_in6*)sa)->sin6_addr);
}

int main(int argc, char *argv[])
{

    int sockfd, numbytes;
    char buf[MAXDATASIZE];
    struct addrinfo hints, *servinfo, *p;
    int rv;
    char s[INET6_ADDRSTRLEN];

    if (argc !=3 ) {
        fprintf(stderr, "usage: host port \n");
        exit(1);
    }

    memset(&hints, 0, sizeof hints);
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;

    fprintf(stdout, "here\n");

    if ((rv = getaddrinfo(argv[1], argv[2], &hints, &servinfo)) != 0) {
        fprintf(stderr, "getaddrinfo: %s\n", gai_strerror(rv));
        return 1;
    }

    fprintf(stdout, "%i\n", rv);
    fprintf(stdout, "%s\n", hints);
    fprintf(stdout, "hints:\n");
    fprintf(stdout, "ai_flags %i\n", hints.ai_flags);
    fprintf(stdout, "ai_family %i\n", hints.ai_family);
    fprintf(stdout, "ai_socktype %i\n", hints.ai_socktype);
    fprintf(stdout, "ai_protocol %i\n", hints.ai_protocol);
    fprintf(stdout, "ai_addrlen %i\n", hints.ai_addrlen);
    fprintf(stdout, "ai_canonname %s\n", hints.ai_canonname);

    fprintf(stdout, "servinfo:\n");
    fprintf(stdout, "ai_flags %i\n", servinfo->ai_flags);
    fprintf(stdout, "ai_family %i\n", servinfo->ai_family);
    fprintf(stdout, "ai_socktype %i\n", servinfo->ai_socktype);
    fprintf(stdout, "ai_protocol %i\n", servinfo->ai_protocol);
    fprintf(stdout, "ai_addrlen %i\n", servinfo->ai_addrlen);
    fprintf(stdout, "ai_canonname %s\n", servinfo->ai_canonname);


    // addrinfo
	// int	ai_flags;	/* AI_PASSIVE, AI_CANONNAME, AI_NUMERICHOST */
	// int	ai_family;	/* PF_xxx */
	// int	ai_socktype;	/* SOCK_xxx */
	// int	ai_protocol;	/* 0 or IPPROTO_xxx for IPv4 and IPv6 */
	// socklen_t ai_addrlen;	/* length of ai_addr */
	// char	*ai_canonname;	/* canonical name for hostname */
	// struct	sockaddr *ai_addr;	/* binary address */
	// struct	addrinfo *ai_next;

}