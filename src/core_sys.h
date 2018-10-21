#ifndef __CORE_SYS__
#define __CORE_SYS__

#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <errno.h>

#include <netinet/tcp.h>
#include <netinet/in.h>
#include <arpa/inet.h> 
#include <sys/socket.h>
#include <sys/types.h>
#include <fcntl.h>

#ifndef EWOULDBLOCK
    #define EWOULDBLOCK EAGAIN
#endif


/* [level][datetime][file][function:][具体打印内容] */
#define LOG(log_level, content) { \
    time_t t;\
    struct tm* lt; \
    /*获取Unix时间戳、转为时间结构。*/ \
	time(&t); lt = localtime(&t);  \
    fprintf(stdout, "[%04d/%02d/%02d][%02d:%02d:%02d][%s][%s][%s:%d]{%s}\n", \
    	lt->tm_year+1900, 1+lt->tm_mon, lt->tm_mday, lt->tm_hour, lt->tm_min, lt->tm_sec, \
    	log_level, \
    	__FILE__, __FUNCTION__, __LINE__, \
    	content);}

#define ERRNO(errno) !errno ? strerror(errno) : "errno no error!"

/* ipv4转换为字符串 */
#define ipv4_to_str(ip, str) sprintf(str, "%d.%d.%d.%d", ip & 0xFF, (ip >> 8) & 0xFF, (ip >> 16) & 0xFF, (ip >> 24) & 0xFF)

#endif