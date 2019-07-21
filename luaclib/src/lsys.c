#define LUA_LIB

#include "../../src/core.h"

// 提供一个精确到微秒的时间戳
static int
lnow(lua_State *L){
	lua_pushnumber(L, now());
	return 1;
}

static int /* 此方法可用于检查是否为有效ipv4地址*/
lipv4(lua_State *L){
    const char *IP = lua_tostring(L, 1);
    if (!IP) return luaL_error(L, "ipv4 error: 请至少传递一个string类型参数\n");
    if (ipv4(IP)) lua_pushboolean(L, 1);
    else lua_pushboolean(L, 0);
    return 1;
}

static int /* 此方法可用于检查是否为有效ipv6地址*/
lipv6(lua_State *L){
    const char *IP = lua_tostring(L, 1);
    if (!IP) return luaL_error(L, "ipv6 error: 请至少传递一个string类型参数\n");
    if (ipv6(IP)) lua_pushboolean(L, 1);
    else lua_pushboolean(L, 0);
    return 1;
}

static int
ldate(lua_State *L){
    const char *fmt = lua_tostring(L, 1);
    if (!fmt) return luaL_error(L, "Date: 错误的格式化方法");
    time_t timestamp = lua_tointeger(L, 2);
    if (0 >= timestamp) timestamp = time(NULL);
    char fmttime[256];
    strftime(fmttime, 256, fmt, localtime(&timestamp));
    lua_pushstring(L, fmttime);
    return 1;
}

static int
lnew_tab(lua_State *L){
	lua_Integer array_size = luaL_checkinteger(L, 1);
	lua_Integer hash_size = luaL_checkinteger(L, 2);
	lua_createtable(L, array_size, hash_size);
	return 1;
}

LUAMOD_API int
luaopen_sys(lua_State *L){
	luaL_checkversion(L);
	luaL_Reg sys_libs[] = {
		{"now", lnow},
		{"ipv4", lipv4},
		{"ipv6", lipv6},
		{"date", ldate},
		{"new_tab", lnew_tab},
		{NULL, NULL}
	};
	luaL_newlib(L, sys_libs);
	return 1;
}
