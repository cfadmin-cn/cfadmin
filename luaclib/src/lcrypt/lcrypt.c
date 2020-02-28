#include "lcrypt.h"

/* -- xor_str -- */
static int lxor_str(lua_State *L) {
  size_t len1,len2;
  const char *s1 = luaL_checklstring(L, 1, &len1);
  const char *s2 = luaL_checklstring(L, 2, &len2);
  if (len2 == 0) {
    return luaL_error(L, "Can't xor empty string");
  }
  luaL_Buffer b;
  char * buffer = luaL_buffinitsize(L, &b, len1);
  int i;
  for (i=0;i<len1;i++) {
    buffer[i] = s1[i] ^ s2[i % len2];
  }
  luaL_addsize(&b, len1);
  luaL_pushresult(&b);
  return 1;
}

static int lrandomkey(lua_State *L) {
  char tmp[8];
  int i;
  char x = 0;
  for (i=0;i<8;i++) {
    tmp[i] = random() & 0xff;
    x ^= tmp[i];
  }
  if (x==0) {
    tmp[0] |= 1;  // avoid 0
  }
  lua_pushlstring(L, tmp, 8);
  return 1;
}
/* -- xor_str -- */


LUAMOD_API int
luaopen_lcrypt(lua_State *L) {
  luaL_checkversion(L);
  luaL_Reg lcrypt[] = {
    {"uuid", luuid},
    { "hashkey", lhashkey },
    { "randomkey", lrandomkey },
    { "desencode", ldesencode },
    { "desdecode", ldesdecode },
    { "hexencode", ltohex },
    { "hexdecode", lfromhex },
    { "hmac64", lhmac64 },
    { "hmac64_md5", lhmac64_md5 },
    { "dhexchange", ldhexchange },
    { "dhsecret", ldhsecret },
    { "base64encode", lb64encode },
    { "base64decode", lb64decode },
    { "urlencode", lurlencode },
    { "urldecode", lurldecode },
    // SHA
    { "md5", lmd5 },
    { "crc32", lcrc32 },
    { "crc64", lcrc64 },
    { "sha1", lsha128 },
    { "sha128", lsha128 },
    { "sha224", lsha224 },
    { "sha256", lsha256 },
    { "sha384", lsha384 },
    { "sha512", lsha512 },
    // HMAC
    { "hmac_md5", lhmac_md5 },
    { "hmac_sha1", lhmac_sha128 },
    { "hmac_sha128", lhmac_sha128 },
    // { "hmac_sha224", lhmac_sha224 },
    { "hmac_sha256", lhmac_sha256 },
    // { "hmac_sha384", lhmac_sha384 },
    { "hmac_sha512", lhmac_sha512 },
    { "hmac_hash", lhmac_hash },
    { "xor_str", lxor_str },
    // 公钥加密 -> 私钥解密
    {"rsa_public_key_encode", lrsa_public_key_encode},
    {"rsa_private_key_decode", lrsa_private_key_decode},
    // 私钥加密 -> 公钥解密
    {"rsa_private_key_encode", lrsa_private_key_encode},
    {"rsa_public_key_decode", lrsa_public_key_decode},
    //shawithrsa
    {"sha128WithRsa_sign", lSha128WithRsa_sign},
    {"sha128WithRsa_verify", lSha128WithRsa_verify},
    {"sha256WithRsa_sign", lSha256WithRsa_sign},
    {"sha256WithRsa_verify", lSha256WithRsa_verify},
    // aes 加密
    {"aes_ecb_encrypt", laes_ecb_encrypt},
    {"aes_cbc_encrypt", laes_cbc_encrypt},
    // {"aes_cfb_encrypt", laes_cfb_encrypt},
    // {"aes_ofb_encrypt", laes_ofb_encrypt},
    // {"aes_ctr_encrypt", laes_ctr_encrypt},
    // aes 解密
    {"aes_ecb_decrypt", laes_ecb_decrypt},
    {"aes_cbc_decrypt", laes_cbc_decrypt},
    // {"aes_cfb_decrypt", laes_cfb_decrypt},
    // {"aes_ofb_decrypt", laes_ofb_decrypt},
    // {"aes_ctr_decrypt", laes_ctr_decrypt},
    { NULL, NULL },
  };
  luaL_newlib(L, lcrypt);
  return 1;
}
