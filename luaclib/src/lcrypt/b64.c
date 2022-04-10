#include "lcrypt.h"

#define BASE64_CHUNK (65535)

#define BASE64_ENC_LENGTH(len) (((len) + 2) / 3 * 4)

#define BASE64_DEC_LENGTH(len) ((len + 3) / 4 * 3)

#define BASE64_URLSAFE(safe, ch, a, b, c, d) \
  if (urlsafe) {            \
    if (ch == a)            \
      ch = b;               \
    else if (ch == c)       \
      ch = d;               \
  }

static inline void encoder(uint8_t *buffer, uint32_t idx, uint8_t code, int32_t urlsafe) {
  static const char b64code[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  uint8_t ch = b64code[code];
  BASE64_URLSAFE(urlsafe, ch, '+', '-', '/', '_');
  /* check encoder */
  buffer[idx] = ch;
}

int lb64encode(lua_State *L) {

  size_t tsize = 0;
  const uint8_t* text = (const uint8_t *)luaL_checklstring(L, 1, &tsize);
  if (!text || tsize == 0)
    return 0;

  int32_t urlsafe = 0;
  if (lua_isboolean(L, 2) && lua_toboolean(L, 2))
    urlsafe = 1;

  int32_t nopadding = 0;
  if (lua_isboolean(L, 3) && lua_toboolean(L, 3))
    nopadding = 1;

  int esize = BASE64_ENC_LENGTH(tsize);

  char *buffer;
  if (tsize <= BASE64_CHUNK)
    buffer = alloca(esize);
  else
    buffer = lua_newuserdata(L, esize);

  int64_t nsize = tsize;
  size_t idx, set, index = 0;

  /* normal encoder */
  for (idx = 0; idx < nsize - 2; idx += 3) {
    set = (text[idx] << 16) | (text[idx + 1] << 8) | (text[idx + 2]);
    encoder((uint8_t*)buffer, index++, set >> 18 & 0x3f, urlsafe);
    encoder((uint8_t*)buffer, index++, set >> 12 & 0x3f, urlsafe);
    encoder((uint8_t*)buffer, index++, set >> 6  & 0x3f, urlsafe);
    encoder((uint8_t*)buffer, index++, set & 0x3f, urlsafe);
  }

  // int padding = tsize - idx;
  /* checked padding. */
  switch (tsize - idx) {
    case 1: /* only 1 char */
      set = text[idx];
      encoder((uint8_t*)buffer, index++, set >> 2, urlsafe);
      encoder((uint8_t*)buffer, index++, (set << 4) & 0x3f, urlsafe);
      if (!nopadding) {
        buffer[index++] = '=';
        buffer[index++] = '=';
      }
      break;
    case 2: /* having 2 char */
      set = text[idx] << 8 | text[idx + 1];
      encoder((uint8_t*)buffer, index++, (set >> 10) & 0x3f, urlsafe);
      encoder((uint8_t*)buffer, index++, (set >>  4) & 0x3f, urlsafe);
      encoder((uint8_t*)buffer, index++, (set <<  2) & 0x3f, urlsafe);
      if (!nopadding)
        buffer[index++] = '=';
      break;
  }
  lua_pushlstring(L, buffer, index);
  return 1;
}

static inline uint8_t decoder(lua_State* L, uint8_t ch, int32_t urlsafe) {
  static const int8_t b64code_idx[] = {
    -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
    -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
    -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  62,  -1,  -1,  -1,  63,
    52,  53,  54,  55,  56,  57,  58,  59,  60,  61,  -1,  -1,  -1,  -1,  -1,  -1,
    -1,   0,   1,   2,   3,   4,   5,   6,   7,   8,   9,  10,  11,  12,  13,  14,
    15,  16,  17,  18,  19,  20,  21,  22,  23,  24,  25,  -1,  -1,  -1,  -1,  -1,
    -1,  26,  27,  28,  29,  30,  31,  32,  33,  34,  35,  36,  37,  38,  39,  40,
    41,  42,  43,  44,  45,  46,  47,  48,  49,  50,  51,  -1,  -1,  -1,  -1,  -1,
    -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
    -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
    -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
    -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
    -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
    -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
    -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
    -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  };
  BASE64_URLSAFE(urlsafe, ch, '-', '+', '_', '/');
  int8_t code = b64code_idx[ch];
  if (code == -1)
    return luaL_error(L, "Invalid base64 decode byte. %d", ch);
  return (uint8_t)code;
}

int lb64decode(lua_State *L) {
  size_t tsize = 0;
  const uint8_t* text = (const uint8_t *)luaL_checklstring(L, 1, &tsize);
  if (!text || tsize == 0)
    return 0;

  int32_t urlsafe = 0;
  if (lua_isboolean(L, 2) && lua_toboolean(L, 2))
    urlsafe = 1;

  int dsize = BASE64_DEC_LENGTH(tsize);

  char *buffer;
  if (tsize <= BASE64_CHUNK)
    buffer = alloca(dsize);
  else
    buffer = lua_newuserdata(L, dsize);

  size_t index = 0, idx = 0;
  uint32_t offsets, i, pos;
  for (idx = 0; idx < tsize;)
  {
    i = 0, pos = 0;
    uint8_t set[] = {0, 0, 0, 0};
    while (idx + pos < tsize && i < 4) {
      uint8_t ch = text[idx + (pos++)];
      if (ch == '=') {
        if (idx + pos < tsize - 2)
          return luaL_error(L, "Invalid base64 decode text.");
        break;
      }
      if (ch == '\n')
        continue;
      set[i++] = decoder(L, ch, urlsafe);
    }
    // printf("pos = %d, set = { %d, %d, %d, %d }\n", idx, set[0], set[1], set[2], set[3]);
    offsets = (set[0] << 18) | (set[1] << 12) | (set[2] << 6) | set[3];
    switch (4 - i){
      case 0:
        /* decode normal character. */
        buffer[index++] = (offsets >> 16);
        buffer[index++] = (offsets >>  8) & 0xFF;;
        buffer[index++] = offsets & 0xFF;
        break;
      case 1:
        /* padding 1 character. */
        buffer[index++] = (offsets >> 16);
        buffer[index++] = (offsets >>  8) & 0xFF;;
        break;
      case 2:
        /* padding 2 character. */
        buffer[index++] = offsets >> 16;
        break;
    }
    idx += pos;
  }
  // printf("ret = %d\n", index);
  lua_pushlstring(L, buffer, index);
  return 1;
}