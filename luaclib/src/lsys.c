#define LUA_LIB

#include "../../src/core.h"

#define hex_char(ch) ({(uint8_t)((ch) > 9 ? (ch) + 55: (ch) + 48);})

#define is_normal_char(ch) ({((ch) >= 'a' && (ch) <= 'z') || ((ch) >= 'A' && (ch) <= 'Z') || ((ch) >= '0' && (ch) <= '9') ? 1 : 0;})

// 提供一个精确到毫秒的时间戳
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
    char fmttime[64];
    time_t t = time(&timestamp);
    strftime(fmttime, 64, fmt, localtime(&t));
    lua_pushstring(L, fmttime);
    return 1;
}

static int /* url编码 */
lurlencode(lua_State *L){
	size_t url_len;
  const char* url = luaL_checklstring(L, 1, &url_len);
	if (!url) return luaL_error(L, "urlencode error: 需要传递一个有效的url字符串!");
	luaL_Buffer convert_url;
	luaL_buffinit(L, &convert_url);
	while (*url) {
		uint8_t ch = (uint8_t)*url++;
		if (ch == ' ') {
			luaL_addlstring(&convert_url, "%20", 3);
			continue;
		}
		if (is_normal_char(ch) || strchr("-_.!~*'()", ch)){
			luaL_addchar(&convert_url, ch);
			continue;
		}
		char ver[3] = {'%', hex_char(((uint8_t)ch) >> 4), hex_char(((uint8_t)ch) & 15)};
		luaL_addlstring(&convert_url, ver, 3);
	}
	luaL_pushresult(&convert_url);
	return 1;
}

static int /* url解码 */
lurldecode(lua_State *L){
	size_t url_len, i = 0, j = 0;
  const char* url = luaL_checklstring(L, 1, &url_len);
	if (!url) return luaL_error(L, "urldecode error: 需要传递一个有效的url字符串!");
	char convert_url[url_len];
	while (i < url_len) {
		if (url[i] != '%') {
			convert_url[j++] = url[i++];
			continue;
		}
		char vert[2] = {url[i + 1], url[i + 2]};
		convert_url[j++] = (uint8_t)((vert[0] - 48 - ((vert[0] >= 'A') ? 7 : 0) - ((vert[0] >= 'a') ? 32 : 0)) * 16 + (vert[1] - 48 - ((vert[1] >= 'A') ? 7 : 0) - ((vert[1] >= 'a') ? 32 : 0)));
		i += 3;
	}
	if (j < i) convert_url[j] = '\0';
	lua_pushstring(L, convert_url);
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
		{"urlencode", lurlencode},
		{"urldecode", lurldecode},
		{NULL, NULL}
	};
	luaL_newlib(L, sys_libs);
	return 1;
}
