#include "lcrypt.h"

/*
# define MD5_DIGEST_LENGTH       16
# define SHA_DIGEST_LENGTH       20
# define SHA224_DIGEST_LENGTH    28
# define SHA256_DIGEST_LENGTH    32
# define SHA384_DIGEST_LENGTH    48
# define SHA512_DIGEST_LENGTH    64
*/

int lhmac_md4(lua_State *L) {
  size_t key_sz = 0;
  size_t text_sz = 0;

  const char * key = luaL_checklstring(L, 1, &key_sz);
  if (!key || key_sz <= 0)
    return luaL_error(L, "Invalid key value.");

  const char * text = luaL_checklstring(L, 2, &text_sz);
  if (!text || text_sz <= 0)
    return luaL_error(L, "Invalid text value.");

  uint32_t result_len = MD4_DIGEST_LENGTH;
  unsigned char result[result_len];

  HMAC(EVP_md4(), key, key_sz, (const unsigned char*)text, text_sz, result, &result_len);

  lua_pushlstring(L, (const char *)result, result_len);
  return 1;
};

int lhmac_md5(lua_State *L) {
  size_t key_sz = 0;
  size_t text_sz = 0;

  const char * key = luaL_checklstring(L, 1, &key_sz);
  if (!key || key_sz <= 0)
    return luaL_error(L, "Invalid key value.");

  const char * text = luaL_checklstring(L, 2, &text_sz);
  if (!text || text_sz <= 0)
    return luaL_error(L, "Invalid text value.");

  uint32_t result_len = MD5_DIGEST_LENGTH;
  unsigned char result[result_len];

  HMAC(EVP_md5(), key, key_sz, (const unsigned char*)text, text_sz, result, &result_len);

  lua_pushlstring(L, (const char *)result, result_len);
  return 1;
};

int lhmac_sha128(lua_State *L) {
  size_t key_sz = 0;
  size_t text_sz = 0;

  const char * key = luaL_checklstring(L, 1, &key_sz);
  if (!key || key_sz <= 0)
    return luaL_error(L, "Invalid key value.");

  const char * text = luaL_checklstring(L, 2, &text_sz);
  if (!text || text_sz <= 0)
    return luaL_error(L, "Invalid text value.");
  
  uint32_t result_len = SHA_DIGEST_LENGTH;
  unsigned char result[result_len];

  HMAC(EVP_sha1(), key, key_sz, (const unsigned char*)text, text_sz, result, &result_len);

  lua_pushlstring(L, (const char *)result, result_len);
  return 1;
};

int lhmac_sha224(lua_State *L) {
  size_t key_sz = 0;
  size_t text_sz = 0;

  const char * key = luaL_checklstring(L, 1, &key_sz);
  if (!key || key_sz <= 0)
    return luaL_error(L, "Invalid key value.");

  const char * text = luaL_checklstring(L, 2, &text_sz);
  if (!text || text_sz <= 0)
    return luaL_error(L, "Invalid text value.");

  uint32_t result_len = SHA224_DIGEST_LENGTH;
  unsigned char result[result_len];

  HMAC(EVP_sha224(), key, key_sz, (const unsigned char*)text, text_sz, result, &result_len);
  
  lua_pushlstring(L, (const char *)result, result_len);
  return 1;
};

int lhmac_sha256(lua_State *L) {
  size_t key_sz = 0;
  size_t text_sz = 0;

  const char * key = luaL_checklstring(L, 1, &key_sz);
  if (!key || key_sz <= 0)
    return luaL_error(L, "Invalid key value.");

  const char * text = luaL_checklstring(L, 2, &text_sz);
  if (!text || text_sz <= 0)
    return luaL_error(L, "Invalid text value.");

  uint32_t result_len = SHA256_DIGEST_LENGTH;
  unsigned char result[result_len];
  HMAC(EVP_sha256(), key, key_sz, (const unsigned char*)text, text_sz, result, &result_len);
  lua_pushlstring(L, (const char *)result, result_len);
  return 1;
};

int lhmac_sha384(lua_State *L) {
  size_t key_sz = 0;
  size_t text_sz = 0;

  const char * key = luaL_checklstring(L, 1, &key_sz);
  if (!key || key_sz <= 0)
    return luaL_error(L, "Invalid key value.");

  const char * text = luaL_checklstring(L, 2, &text_sz);
  if (!text || text_sz <= 0)
    return luaL_error(L, "Invalid text value.");

  uint32_t result_len = SHA384_DIGEST_LENGTH;
  unsigned char result[result_len];
  HMAC(EVP_sha384(), key, key_sz, (const unsigned char*)text, text_sz, result, &result_len);
  lua_pushlstring(L, (const char *)result, result_len);
  return 1;
};

int lhmac_sha512(lua_State *L) {
  size_t key_sz = 0;
  size_t text_sz = 0;

  const char * key = luaL_checklstring(L, 1, &key_sz);
  if (!key || key_sz <= 0)
    return luaL_error(L, "Invalid key value.");

  const char * text = luaL_checklstring(L, 2, &text_sz);
  if (!text || text_sz <= 0)
    return luaL_error(L, "Invalid text value.");

  uint32_t result_len = SHA512_DIGEST_LENGTH;
  unsigned char result[result_len];
  HMAC(EVP_sha512(), key, key_sz, (const unsigned char*)text, text_sz, result, &result_len);
  lua_pushlstring(L, (const char *)result, result_len);
  return 1;
};

int lhmac_ripemd160(lua_State *L) {
  size_t key_sz = 0;
  size_t text_sz = 0;

  const char * key = luaL_checklstring(L, 1, &key_sz);
  if (!key || key_sz <= 0)
    return luaL_error(L, "Invalid key value.");

  const char * text = luaL_checklstring(L, 2, &text_sz);
  if (!text || text_sz <= 0)
    return luaL_error(L, "Invalid text value.");

  uint32_t result_len = RIPEMD160_DIGEST_LENGTH;
  unsigned char result[result_len];
  HMAC(EVP_ripemd160(), key, key_sz, (const unsigned char*)text, text_sz, result, &result_len);
  lua_pushlstring(L, (const char *)result, result_len);
  return 1;
};