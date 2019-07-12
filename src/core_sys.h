#ifndef __CORE_SYS__
#define __CORE_SYS__

#include <stdio.h>
#include <stddef.h>
#include <stdint.h>
#include <stdarg.h>
#include <string.h>
#include <unistd.h>

#include <assert.h>
#include <math.h>
#include <limits.h>
#include <time.h>
#include <errno.h>

#include <netinet/tcp.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/time.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <fcntl.h>

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#ifndef EWOULDBLOCK
    #define EWOULDBLOCK EAGAIN
#endif

#define non_blocking(socket) (fcntl(socket, F_SETFL, fcntl(socket, F_GETFL, 0) | O_NONBLOCK));

/* [datetime][level][file][function][line][具体打印内容] */
#define LOG(log_level, content) { \
    time_t t; struct tm* lt; \
    /*获取Unix时间戳、转为时间结构。*/ \
	time(&t); lt = localtime(&t);  \
    fprintf(stdout, "[%04d/%02d/%02d][%02d:%02d:%02d][%s][%s][%s:%d] : %s\n", \
    	lt->tm_year+1900, 1+lt->tm_mon, lt->tm_mday, lt->tm_hour, lt->tm_min, lt->tm_sec, \
    	log_level, \
    	__FILE__, __FUNCTION__, __LINE__, \
    	content);}

/* 微秒级时间戳函数 */
double now(void);

/* 检查是否为有效ipv4地址 */
int ipv4(const char *IP);

/* 检查是否为有效ipv6地址 */
int ipv6(const char *IP);

#endif
