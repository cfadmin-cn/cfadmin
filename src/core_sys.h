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

#include <netdb.h>
#include <netinet/tcp.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/un.h>
#include <sys/time.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <fcntl.h>

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#if defined(__MSYS__)
  #define __OS__ ("Windows")
#elif defined(__APPLE__)
  #define __OS__ ("Apple")
#elif defined(linux) || defined(__linux) || defined(__linux__)
  #define __OS__ ("Linux")
#elif defined(__OpenBSD__) || defined(__NetBSD__) || defined(__FreeBSD__) || defined(__DragonFly__)
  #define __OS__ ("BSD")
#else
  #define __OS__ ("Unix")
#endif

#if LUA_VERSION_NUM >= 504
  #ifndef CO_GCRESET
    #define CO_GCRESET(L) lua_gc(L, LUA_GCGEN, NULL, NULL);
  #endif
  #ifndef CO_RESUME
    #define CO_RESUME(L, from, nargs) ({int nout = 0; lua_resume(L, from, nargs, &nout);})
  #endif
#else
  #ifndef CO_GCRESET
    #define CO_GCRESET(L)
  #endif
  #ifndef CO_RESUME
    #define CO_RESUME(L, from, nargs) lua_resume(L, from, nargs)
  #endif
#endif

#ifndef EWOULDBLOCK
    #define EWOULDBLOCK EAGAIN
#endif

#define non_blocking(socket) (fcntl(socket, F_SETFL, fcntl(socket, F_GETFL, 0) | O_NONBLOCK));

#define non_delay(socket) ({int Enable = 1; setsockopt(socket, IPPROTO_TCP, TCP_NODELAY, &Enable, sizeof(Enable));})

/* [datetime][level][file][function][line][具体打印内容] */
#define LOG(LEVEL, CONTENT) { \
  time_t t = time(NULL); struct tm* lt = localtime(&t);  \
  fprintf(stdout, "[%04d/%02d/%02d][%02d:%02d:%02d][%s][%s][%s:%d] : %s\n", \
    lt->tm_year + 1900, 1 + lt->tm_mon, lt->tm_mday, lt->tm_hour, lt->tm_min, lt->tm_sec, \
    LEVEL, __FILE__, __FUNCTION__, __LINE__, CONTENT); \
  fflush(stdout); \
}

/* 微秒级时间戳函数 */
double now(void);

/* 检查是否为有效ipv4地址 */
int ipv4(const char *IP);

/* 检查是否为有效ipv6地址 */
int ipv6(const char *IP);

/* 返回当前操作系统类型 */
const char* os(void);

#endif
