#include "lcrypt.h"

/*
# define MD5_DIGEST_LENGTH       16
# define SHA_DIGEST_LENGTH       20
# define SHA224_DIGEST_LENGTH    28
# define SHA256_DIGEST_LENGTH    32
# define SHA384_DIGEST_LENGTH    48
# define SHA512_DIGEST_LENGTH    64
*/

static inline int sha_digest(lua_State *L, const char* text, size_t tsize, const EVP_MD *type) {
  unsigned int rsize = EVP_MAX_MD_SIZE;
  unsigned char result[rsize];
  EVP_Digest(text, tsize, result, &rsize, type, NULL);
  lua_pushlstring(L, (const char*)result, rsize);
  return 1;
}

int lmd4(lua_State *L) {
  size_t sz = 0;
  const char * text = luaL_checklstring(L, 1, &sz);
  if (!text || sz <= 0)
    return luaL_error(L, "Invalid text value.");
  return sha_digest(L, text, sz, EVP_md4());
}

int lmd5(lua_State *L) {
  size_t sz = 0;
  const char * text = luaL_checklstring(L, 1, &sz);
  if (!text || sz <= 0)
    return luaL_error(L, "Invalid text value.");
  return sha_digest(L, text, sz, EVP_md5());
};

int lsha128(lua_State *L) {
  size_t sz = 0;
  const char * text = luaL_checklstring(L, 1, &sz);
  if (!text || sz <= 0)
    return luaL_error(L, "Invalid text value.");
  return sha_digest(L, text, sz, EVP_sha1());
};

int lsha224(lua_State *L) {
  size_t sz = 0;
  const char * text = luaL_checklstring(L, 1, &sz);
  if (!text || sz <= 0)
    return luaL_error(L, "Invalid text value.");
  return sha_digest(L, text, sz, EVP_sha224());
};

int lsha256(lua_State *L) {
  size_t sz = 0;
  const char * text = luaL_checklstring(L, 1, &sz);
  if (!text || sz <= 0)
    return luaL_error(L, "Invalid text value.");
  return sha_digest(L, text, sz, EVP_sha256());
};

int lsha384(lua_State *L) {
  size_t sz = 0;
  const char * text = luaL_checklstring(L, 1, &sz);
  if (!text || sz <= 0)
    return luaL_error(L, "Invalid text value.");
  return sha_digest(L, text, sz, EVP_sha384());
};

int lsha512(lua_State *L) {
  size_t sz = 0;
  const char * text = luaL_checklstring(L, 1, &sz);
  if (!text || sz <= 0)
    return luaL_error(L, "Invalid text value.");
  return sha_digest(L, text, sz, EVP_sha512());
};

int lripemd160(lua_State *L) {
  size_t sz = 0;
  const char * text = luaL_checklstring(L, 1, &sz);
  if (!text || sz <= 0)
    return luaL_error(L, "Invalid text value.");
  return sha_digest(L, text, sz, EVP_ripemd160());
};