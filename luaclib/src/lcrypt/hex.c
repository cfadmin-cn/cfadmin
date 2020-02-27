#include "lcrypt.h"

#define HEX(v, c) { char tmp = (char) c; if (tmp >= '0' && tmp <= '9') { v = tmp-'0'; } else { v = tmp - 'a' + 10; } }

int ltohex(lua_State *L) {
  static char hex[] = "0123456789abcdef";
  size_t sz = 0;
  const uint8_t * text = (const uint8_t *)luaL_checklstring(L, 1, &sz);
  char tmp[SMALL_CHUNK];
  char *buffer = tmp;
  if (sz > SMALL_CHUNK/2) {
    buffer = lua_newuserdata(L, sz * 2);
  }
  int i;
  for (i=0;i<sz;i++) {
    buffer[i*2] = hex[text[i] >> 4];
    buffer[i*2+1] = hex[text[i] & 0xf];
  }
  lua_pushlstring(L, buffer, sz * 2);
  return 1;
}

int lfromhex(lua_State *L) {
  size_t sz = 0;
  const char * text = luaL_checklstring(L, 1, &sz);
  if (sz & 1) {
    return luaL_error(L, "Invalid hex text size %d", (int)sz);
  }
  char tmp[SMALL_CHUNK];
  char *buffer = tmp;
  if (sz > SMALL_CHUNK*2) {
    buffer = lua_newuserdata(L, sz / 2);
  }
  int i;
  for (i=0;i<sz;i+=2) {
    uint8_t hi,low;
    HEX(hi, text[i]);
    HEX(low, text[i+1]);
    if (hi > 16 || low > 16) {
      return luaL_error(L, "Invalid hex text", text);
    }
    buffer[i/2] = hi<<4 | low;
  }
  lua_pushlstring(L, buffer, i/2);
  return 1;
}