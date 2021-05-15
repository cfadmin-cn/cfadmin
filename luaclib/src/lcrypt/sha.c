#include "lcrypt.h"

/*
# define MD5_DIGEST_LENGTH       16
# define SHA_DIGEST_LENGTH       20
# define SHA224_DIGEST_LENGTH    28
# define SHA256_DIGEST_LENGTH    32
# define SHA384_DIGEST_LENGTH    48
# define SHA512_DIGEST_LENGTH    64
*/

int lmd4(lua_State *L) {
  size_t sz = 0;
  const char * text = luaL_checklstring(L, 1, &sz);
  if (!text || sz <= 0)
    return luaL_error(L, "Invalid text value.");
  unsigned char result[MD4_DIGEST_LENGTH];
  MD4((const unsigned char*) text, sz, result);
  lua_pushlstring(L, (const char *)result, MD4_DIGEST_LENGTH);
  return 1;
};

int lmd5(lua_State *L) {
  size_t sz = 0;
  const char * text = luaL_checklstring(L, 1, &sz);
  if (!text || sz <= 0)
    return luaL_error(L, "Invalid text value.");
  unsigned char result[MD5_DIGEST_LENGTH];
  MD5((const unsigned char*) text, sz, result);
  lua_pushlstring(L, (const char *)result, MD5_DIGEST_LENGTH);
  return 1;
};

int lsha128(lua_State *L) {
  size_t sz = 0;
  const char * text = luaL_checklstring(L, 1, &sz);
  if (!text || sz <= 0)
    return luaL_error(L, "Invalid text value.");
  unsigned char result[SHA_DIGEST_LENGTH];
  SHA1((const unsigned char*) text, sz, result);
  lua_pushlstring(L, (const char *)result, SHA_DIGEST_LENGTH);
  return 1;
};

int lsha224(lua_State *L) {
  size_t sz = 0;
  const char * text = luaL_checklstring(L, 1, &sz);
  if (!text || sz <= 0)
    return luaL_error(L, "Invalid text value.");
  unsigned char result[SHA224_DIGEST_LENGTH];
  SHA224((const unsigned char*) text, sz, result);
  lua_pushlstring(L, (const char *)result, SHA224_DIGEST_LENGTH);
  return 1;
};

int lsha256(lua_State *L) {
  size_t sz = 0;
  const char * text = luaL_checklstring(L, 1, &sz);
  if (!text || sz <= 0)
    return luaL_error(L, "Invalid text value.");
  unsigned char result[SHA256_DIGEST_LENGTH];
  SHA256((const unsigned char*) text, sz, result);
  lua_pushlstring(L, (const char *)result, SHA256_DIGEST_LENGTH);
  return 1;
};

int lsha384(lua_State *L) {
  size_t sz = 0;
  const char * text = luaL_checklstring(L, 1, &sz);
  if (!text || sz <= 0)
    return luaL_error(L, "Invalid text value.");
  unsigned char result[SHA384_DIGEST_LENGTH];
  SHA384((const unsigned char*) text, sz, result);
  lua_pushlstring(L, (const char *)result, SHA384_DIGEST_LENGTH);
  return 1;
};

int lsha512(lua_State *L) {
  size_t sz = 0;
  const char * text = luaL_checklstring(L, 1, &sz);
  if (!text || sz <= 0)
    return luaL_error(L, "Invalid text value.");
  unsigned char result[SHA512_DIGEST_LENGTH];
  SHA512((const unsigned char*) text, sz, result);
  lua_pushlstring(L, (const char *)result, SHA512_DIGEST_LENGTH);
  return 1;
};

int lripemd160(lua_State *L) {
  size_t sz = 0;
  const char * text = luaL_checklstring(L, 1, &sz);
  if (!text || sz <= 0)
    return luaL_error(L, "Invalid text value.");
  unsigned char result[RIPEMD160_DIGEST_LENGTH];
  RIPEMD160((const unsigned char*) text, sz, result);
  lua_pushlstring(L, (const char *)result, RIPEMD160_DIGEST_LENGTH);
  return 1;
};