#include "core_sys.h"

double
now(){
	struct timeval now;
	gettimeofday(&now, NULL);
	return (double)((double)now.tv_sec + (double)now.tv_usec / 1000000);
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