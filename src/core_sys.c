#include "core_sys.h"

#ifdef __MSYS__
  const char *__OS__ = "Windows";
#endif

#if !defined(__MSYS__) && (defined(__linux) || defined(__linux__))
  const char *__OS__ = "Linux";
#endif

#ifdef __APPLE__
  const char *__OS__ = "Apple";
#endif

#if defined(__OpenBSD__) || defined(__NetBSD__) || defined(__FreeBSD__)
  const char *__OS__ = "Unix";
#endif

 /* 此方法提供一个精确到微秒级的时间戳 */
double now(void){
	struct timespec now = {};
	clock_gettime(CLOCK_REALTIME, &now);
	return now.tv_sec + now.tv_nsec * 1e-9;
}

/* 此方法可用于检查是否为有效ipv4地址*/
int ipv4(const char *IP){
	if (!IP) return 0;
  struct in_addr addr = {};
  if (inet_pton(AF_INET, IP, &addr) == 1) return 1;
  return 0;
}

/* 此方法可用于检查是否为有效ipv6地址*/
int ipv6(const char *IP){
	if (!IP) return 0;
  struct in6_addr addr = {};
  if (inet_pton(AF_INET6, IP, &addr) == 1) return 1;
  return 0;
}

/* 返回当前操作系统类型 */
const char* os(void) {
  return __OS__;
}