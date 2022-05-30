#include "lcrypt.h"
#include <ctype.h>

static char lencode[] = "0123456789abcdef";

static char hencode[] = "0123456789ABCDEF";

static const char deindex[256] = {
  -1,     -1,     -1,     -1,     -1,     -1,     -1,     -1,
  -1,     -1,     -1,     -1,     -1,     -1,     -1,     -1,
  -1,     -1,     -1,     -1,     -1,     -1,     -1,     -1,
  -1,     -1,     -1,     -1,     -1,     -1,     -1,     -1,
  -1,     -1,     -1,     -1,     -1,     -1,     -1,     -1,
  -1,     -1,     -1,     -1,     -1,     -1,     -1,     -1,
   0,      1,      2,      3,      4,      5,      6,      7,
   8,      9,     -1,     -1,     -1,     -1,     -1,     -1,
  -1,     10,     11,     12,     13,     14,     15,     -1,
  -1,     -1,     -1,     -1,     -1,     -1,     -1,     -1,
  -1,     -1,     -1,     -1,     -1,     -1,     -1,     -1,
  -1,     -1,     -1,     -1,     -1,     -1,     -1,     -1,
  -1,     10,     11,     12,     13,     14,     15,     -1,
  -1,     -1,     -1,     -1,     -1,     -1,     -1,     -1,
  -1,     -1,     -1,     -1,     -1,     -1,     -1,     -1,
  -1,     -1,     -1,     -1,     -1,     -1,     -1,     -1,
  -1,     -1,     -1,     -1,     -1,     -1,     -1,     -1,
  -1,     -1,     -1,     -1,     -1,     -1,     -1,     -1,
  -1,     -1,     -1,     -1,     -1,     -1,     -1,     -1,
  -1,     -1,     -1,     -1,     -1,     -1,     -1,     -1,
  -1,     -1,     -1,     -1,     -1,     -1,     -1,     -1,
  -1,     -1,     -1,     -1,     -1,     -1,     -1,     -1,
  -1,     -1,     -1,     -1,     -1,     -1,     -1,     -1,
  -1,     -1,     -1,     -1,     -1,     -1,     -1,     -1,
  -1,     -1,     -1,     -1,     -1,     -1,     -1,     -1,
  -1,     -1,     -1,     -1,     -1,     -1,     -1,     -1,
  -1,     -1,     -1,     -1,     -1,     -1,     -1,     -1,
  -1,     -1,     -1,     -1,     -1,     -1,     -1,     -1,
  -1,     -1,     -1,     -1,     -1,     -1,     -1,     -1,
  -1,     -1,     -1,     -1,     -1,     -1,     -1,     -1,
  -1,     -1,     -1,     -1,     -1,     -1,     -1,     -1,
  -1,     -1,     -1,     -1,     -1,     -1,     -1,     -1,
};

int lfromhex(lua_State *L) {
  size_t tsize = 0;
  const uint8_t* text = (const uint8_t *)luaL_checklstring(L, 1, &tsize);
  if (!text || tsize < 2)
    return luaL_error(L, "Invalid hexdecode text size %d", (int)tsize);

  luaL_Buffer B;
  luaL_buffinit(L, &B);

  size_t idx = 0; int8_t hi; int8_t lo;

  while (idx < tsize){
    /* 跳过空格 */
    while(isspace((uint8_t)text[idx]))
      idx++;
    if (idx >= tsize)
      break;
    if (idx + 1 == tsize)
      return luaL_error(L, "Invalid hexdecode ending.");
    /* 解码计算 */
    hi = deindex[text[idx++]]; lo = deindex[text[idx++]];
    if (hi == -1 || lo == -1)
      return luaL_error(L, "Invalid hexdecode char pos between %d and %d", idx - 2, idx - 1);
    /* 还原数据 */
    luaL_addchar(&B, hi << 4 | lo);
  }
  luaL_pushresult(&B);
  return 1;
}

int ltohex(lua_State *L) {
  size_t tsize = 0;
  const uint8_t* text = (const uint8_t *)luaL_checklstring(L, 1, &tsize);
  if (!text || tsize == 0)
    return luaL_error(L, "Invalid hexencode text size %d", (int)tsize);

  /* 默认使用小写编码 */
  const char *etable = lencode;
  if (lua_isboolean(L, 2) && lua_toboolean(L, 2))
    etable = hencode;

  /* 编码之间加上空格 */
  size_t n = 2;
  if (lua_isboolean(L, 3) && lua_toboolean(L, 3))
    n = 3;

  luaL_Buffer B;
  luaL_buffinit(L, &B);

  uint8_t code;
  size_t i = 0;
  while (i < tsize)
  {
    code = text[i++];
    luaL_addchar(&B, etable[code >> 4]);
    luaL_addchar(&B, etable[code & 0xF]);
    if (n == 3 && i < tsize) /* 编码结尾不添加空格 */
      luaL_addchar(&B, ' ');
  }
  luaL_pushresult(&B);
  return 1;
}
