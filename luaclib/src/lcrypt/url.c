#include "lcrypt.h"

#define hex_char(ch) ({(uint8_t)((ch) > 9 ? (ch) + 55: (ch) + 48);})

#define is_normal_char(ch) ({((ch) >= 'a' && (ch) <= 'z') || ((ch) >= 'A' && (ch) <= 'Z') || ((ch) >= '0' && (ch) <= '9') ? 1 : 0;})

/* url编码 */
int lurlencode(lua_State *L){
	size_t url_len = 0;
	const char* url = luaL_checklstring(L, 1, &url_len);
	if (!url)
		return luaL_error(L, "Invalid url text");

	luaL_Buffer convert_url;
	luaL_buffinit(L, &convert_url);

	int index;
	for (index = 0; index < url_len;) {
		uint8_t ch = (uint8_t)url[index++];
		if (ch == (uint8_t)' ') {
			luaL_addlstring(&convert_url, "%20", 3);
			continue;
		}
		if (is_normal_char(ch) || strchr("-_.!~*'()", ch)) {
			luaL_addchar(&convert_url, ch);
			continue;
		}
		char vert[] = {'%', hex_char(((uint8_t)ch) >> 4), hex_char(((uint8_t)ch) & 0xF)};
		luaL_addlstring(&convert_url, (const char *)vert, 3);
	}

	luaL_pushresult(&convert_url);
	return 1;
}

/* url解码 */
int lurldecode(lua_State *L){
	size_t url_len = 0;
	const char* url = luaL_checklstring(L, 1, &url_len);
	if (!url)
		return luaL_error(L, "Invalid url text");

	luaL_Buffer convert_url;
	luaL_buffinit(L, &convert_url);

	int index;
	for (index = 0; index < url_len;) {

		uint8_t ch = (uint8_t)url[index++];
		if (ch != (uint8_t)'%') {
			luaL_addchar(&convert_url, ch == (uint8_t)'+' ? (uint8_t)' ' : ch);
			continue;
		}

		char vert[2];
		if (index++ == url_len) {
			luaL_addchar(&convert_url, '%');
			break;
		}
		vert[0] = url[index - 1];

		if (index++ == url_len) {
			luaL_addlstring(&convert_url, url + url_len - 2, 2);
			break;
		}
		vert[1] = url[index - 1];
		luaL_addchar(&convert_url, (uint8_t)((vert[0] - 48 - ((vert[0] >= 'A') ? 7 : 0) - ((vert[0] >= 'a') ? 32 : 0)) * 16 + (vert[1] - 48 - ((vert[1] >= 'A') ? 7 : 0) - ((vert[1] >= 'a') ? 32 : 0))));
	}

	luaL_pushresult(&convert_url);
	return 1;
}
