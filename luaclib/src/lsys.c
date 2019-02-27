#define LUA_LIB

#include "../../src/core.h"

// 提供一个精确到毫秒的时间戳来解决os.clock()返回负数
static int
lnow(lua_State *L){
	struct timeval now;
	gettimeofday(&now, NULL);
	lua_pushnumber(L, (double)((double)now.tv_sec + (double)now.tv_usec / 1000000));
	return 1;
}

int /* 此方法可用于检查是否为有效ipv4地址*/
lipv4(lua_State *L){
    const char *IP = lua_tostring(L, 1);
    if (!IP) return luaL_error(L, "ipv4 error: 请至少传递一个string类型参数\n");
    struct in_addr addr;
    if (inet_pton(AF_INET, IP, &addr) != 1) return 0; /* 转换失败*/
    /* 转换成功*/
    lua_pushboolean(L, 1);
    return 1;
}

int /* 此方法可用于检查是否为有效ipv6地址*/
lipv6(lua_State *L){
    const char *IP = lua_tostring(L, 1);
    if (!IP) return luaL_error(L, "ipv6 error: 请至少传递一个string类型参数\n");
    struct in6_addr addr;
    if (inet_pton(AF_INET6, IP, &addr) != 1) return 0; /* 转换失败*/
    /* 转换成功*/
    lua_pushboolean(L, 1);
    return 1;
}

LUAMOD_API int
luaopen_sys(lua_State *L){
    luaL_checkversion(L);
    luaL_Reg sys_libs[] = {
        {"now", lnow},
        {"ipv4", lipv4},
        {"ipv6", lipv6},
        {NULL, NULL}
    };
    luaL_newlib(L, sys_libs);
    return 1;
}