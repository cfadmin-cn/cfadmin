#include "core_sys.h"

double /* 此方法提供一个精确到微秒级的时间戳 */
now(void){
	struct timespec now;
	clock_gettime(CLOCK_REALTIME, &now);
	return now.tv_sec + now.tv_nsec * 1e-9;
}

int /* 此方法可用于检查是否为有效ipv4地址*/
ipv4(const char *IP){
	if (!IP) return 0;
  struct in_addr addr;
  if (inet_pton(AF_INET, IP, &addr) == 1) return 1;
  return 0;
}

int /* 此方法可用于检查是否为有效ipv6地址*/
ipv6(const char *IP){
	if (!IP) return 0;
  struct in6_addr addr;
  if (inet_pton(AF_INET6, IP, &addr) == 1) return 1;
  return 0;
}
