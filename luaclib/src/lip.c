#define LUA_LIB

#include "../../src/core.h"

int /* 此方法可用于检查是否为有效ipv4地址*/
ipv4(lua_State *L){
    const char *IP = lua_tostring(L, 1);
    if (!IP) return luaL_error(L, "ipv4 error: 请至少传递一个参数\n");
    struct in_addr addr;
    if (inet_pton(AF_INET, IP, &addr) != 1) return 0; /* 转换失败*/
    /* 转换成功*/
    lua_pushboolean(L, 1);
    return 1;
}

int /* 此方法可用于检查是否为有效ipv6地址*/
ipv6(lua_State *L){
    const char *IP = lua_tostring(L, 1);
    if (!IP) return luaL_error(L, "ipv6 error: 请至少传递一个参数\n");
    struct in6_addr addr;
    if (inet_pton(AF_INET6, IP, &addr) != 1) return 0; /* 转换失败*/
    /* 转换成功*/
    lua_pushboolean(L, 1);
    return 1;
}

LUAMOD_API int
luaopen_ip(lua_State *L){
    luaL_checkversion(L);
    luaL_Reg ip_libs[] = {
        {"ipv4", ipv4},
        {"ipv6", ipv6},
        {NULL, NULL}
    };
    luaL_newlib(L, ip_libs);
    return 1;
}