#include <stdio.h>
#include <stdlib.h>

#include <sys/socket.h>
#include <sys/types.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>

#include <fcntl.h>
#include <errno.h>

#include <openssl/ssl.h>
#include <openssl/err.h>

#define IP "183.232.231.173"
#define PORT 443

#define non_blocking(socket) ({fcntl(socket, F_SETFL, fcntl(socket, F_GETFL, 0) | O_NONBLOCK);});

int
create_socket(const char* ip, int port){

    int client, err = 0;

    client = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);

    struct sockaddr_in sockclient;
    memset (&sockclient, 0, sizeof(sockclient));
    sockclient.sin_family      = AF_INET;
    sockclient.sin_port        = htons(port);       /* Server Port number */
    sockclient.sin_addr.s_addr = inet_addr(ip);     /* Server IP */

    non_blocking(client);

    err = connect(client, (struct sockaddr*) &sockclient, sizeof(sockclient));
    if (err >= 0 || errno != EINPROGRESS){
        return -1;
    }

    return client;
}


int main(int argc, char const *argv[])
{
    SSL_CTX *ctx;
    SSL *ssl;

    ctx = SSL_CTX_new(SSLv23_method());
    // ctx = SSL_CTX_new(TLS_method());
    ssl = SSL_new(ctx);

    int s = create_socket(IP, PORT);

    printf("s = %d\n", s);

    SSL_set_fd(ssl, s);

    SSL_set_connect_state(ssl);

    while (1){
        sleep(1);
        int conn_status = SSL_connect(ssl);
        if (1 == conn_status){
            printf("握手完成.\n");
            break;
        }
        int statu_code = SSL_get_error(ssl, conn_status);
        if (statu_code) {
            if (statu_code & (SSL_ERROR_WANT_WRITE | SSL_ERROR_WANT_READ)){
                printf("statu_code = %d, 需要继续握手!\n", statu_code);
                continue;
            }
        }
    }
    FILE *f = fopen("index.html", "w+");
    SSL_write(ssl, "GET / HTTP/1.1\r\n\r\n", 22);
    int count = 0;
    errno = 0;
    while (1) {
        char buf[4096];
        int status = SSL_read(ssl, buf, 4096);
        if (status > 0) {
            fwrite(buf, status, status, f);
            continue;
        }
        if (status < 0 || errno == EAGAIN){
            printf("status = %d, errno = %d, err = %d\n", status, errno, SSL_get_error(ssl, status));
            if (count > 1){
                break;
            }
            count++;
            sleep(1);
        }
    }

    // int err = SSL_connect(ssl);

    // if(err < 0) {
    //     int statu_code = SSL_get_error(ssl, err);
    //     printf("statu_code = %d\n", statu_code);
    //     // printf("SSL_ERROR_WANT_CONNECT : %d\n", SSL_ERROR_WANT_CONNECT);
    //     // printf("SSL_ERROR_WANT_READ : %d\n", SSL_ERROR_WANT_READ);
    //     // printf("SSL_ERROR_WANT_WRITE : %d\n", SSL_ERROR_WANT_WRITE);
    //     switch(statu_code){
    //         case SSL_ERROR_WANT_CONNECT:
    //             printf("SSL_ERROR_WANT_CONNECT\n");
    //         case SSL_ERROR_WANT_READ:
    //             printf("SSL_ERROR_WANT_READ\n");
    //         case SSL_ERROR_WANT_WRITE:
    //             printf("SSL_ERROR_WANT_WRITE\n");
    //     }
    // }

	return 0;
}