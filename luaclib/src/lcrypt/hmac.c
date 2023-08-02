#include "lcrypt.h"

/*
# define MD5_DIGEST_LENGTH       16
# define SHA_DIGEST_LENGTH       20
# define SHA224_DIGEST_LENGTH    28
# define SHA256_DIGEST_LENGTH    32
# define SHA384_DIGEST_LENGTH    48
# define SHA512_DIGEST_LENGTH    64
*/

static inline int hmac_digest(lua_State *L, const char *text, size_t tsize, const char *key, size_t ksize, const EVP_MD *md) {
  unsigned int len = EVP_MAX_MD_SIZE;
  unsigned char resualt[EVP_MAX_MD_SIZE];
  HMAC(md, key, ksize, (unsigned char *)text, tsize, resualt, &len);
  lua_pushlstring(L, (const char *)resualt, len);
  return 1;
}

int lhmac_md4(lua_State *L) {
  size_t key_sz = 0;
  size_t text_sz = 0;

  const char * key = luaL_checklstring(L, 1, &key_sz);
  if (!key || key_sz <= 0)
    return luaL_error(L, "Invalid key value.");

  const char * text = luaL_checklstring(L, 2, &text_sz);
  if (!text || text_sz <= 0)
    return luaL_error(L, "Invalid text value.");

  return hmac_digest(L, text, text_sz, key, key_sz, EVP_md4());
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

  return hmac_digest(L, text, text_sz, key, key_sz, EVP_md5());
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
  
  return hmac_digest(L, text, text_sz, key, key_sz, EVP_sha1());
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

  return hmac_digest(L, text, text_sz, key, key_sz, EVP_sha224());
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

  return hmac_digest(L, text, text_sz, key, key_sz, EVP_sha256());
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

  return hmac_digest(L, text, text_sz, key, key_sz, EVP_sha384());
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

  return hmac_digest(L, text, text_sz, key, key_sz, EVP_sha512());
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

  return hmac_digest(L, text, text_sz, key, key_sz, EVP_ripemd160());
};