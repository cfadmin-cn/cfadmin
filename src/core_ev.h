#ifndef __CORE_EV__
#define __CORE_EV__

/* 关闭3.x版本兼容选择特性 */
#define EV_COMPAT3 0

#define EV_FEATURES (1 | 2 | 4 | 8 | 32 | 64)

#define EV_VERIFY 3

#define EV_USE_4HEAP 1

#define EV_HEAP_CACHE_AT 1

/* 单进程/单线程模型 */
#define EV_NO_SMP 1
#define EV_NO_THREADS 1

/* eventfd 与 signalfd */
#if defined(__linux) || defined(__linux__)
	#define EV_USE_INOTIFY 1
	#define EV_USE_SIGNALFD 1
	#define EV_USE_EVENTFD 1
    #define EV_USE_EPOLL 1
#endif

#if defined(__APPLE__) || defined(__OpenBSD__) || defined(__NetBSD__) || defined(__FreeBSD__)
    #define EV_USE_KQUEUE 1
#endif

#include <ev.h>

#endif