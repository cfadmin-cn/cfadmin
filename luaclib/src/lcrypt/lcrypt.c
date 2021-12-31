#include "lcrypt.h"

/* -- xor_str -- */
static int lxor_str(lua_State *L) {
  size_t len1 = 0;
  const char *s1 = luaL_checklstring(L, 1, &len1);
  if (!s1 || len1 == 0)
    return luaL_error(L, "Can't xor empty string 1.");

  size_t len2 = 0;
  const char *s2 = luaL_checklstring(L, 2, &len2);
  if (!s2 || len2 == 0)
    return luaL_error(L, "Can't xor empty string 2.");

  luaL_Buffer b;
  char * buffer = luaL_buffinitsize(L, &b, len1);

  int i;
  for (i = 0; i < len1; i ++)
    buffer[i] = s1[i] ^ s2[i % len2];

  luaL_addsize(&b, len1);
  luaL_pushresult(&b);
  return 1;
}

static int lrandomkey(lua_State *L) {
  lua_Integer len = lua_tointeger(L, 1);
  if (len < 8 || len > 64)
    return luaL_error(L, "randomkey error: 8 <= len <= 64.");

  uint8_t random_buf[len]; RAND_bytes(random_buf, len);
  uint8_t random_key[len]; RAND_bytes(random_key, len);
  uint8_t random_tmp[len]; RAND_bytes(random_tmp, len);

  int i;
  for (i = 0; i < len; i++)
    random_buf[i] = ((random_key[i] ^ random_tmp[i]) ^ random_buf[i]) & 0xff;

  lua_pushlstring(L, (const char *)random_buf, len);
  return 1;
}
/* -- xor_str -- */


#define lua_set_key_INT(L, key, value) ({ lua_pushstring((L), (key)); lua_pushinteger((L), (value)); lua_rawset((L), -3); })
#define lua_set_key_STR(L, key, value) ({ lua_pushstring((L), (key)); lua_pushstring((L), (value)); lua_rawset((L), -3); })
#define lua_set_key_PTR(L, key, value) ({ lua_pushstring((L), (key)); lua_pushlightuserdata((L), (void*)(value)); lua_rawset((L), -3); })

static int crypt_set_key_value(lua_State *L) {
  /* OPENSSL VERSION NUMBER */
  lua_set_key_INT(L, "OPENSSL_VERSION_NUMBER", OPENSSL_VERSION_NUMBER);
  lua_set_key_STR(L, "OPENSSL_VERSION_TEXT", OPENSSL_VERSION_TEXT);

  /* 增加rsa填充方式常量 */
  lua_set_key_INT(L, "RSA_NO_PADDING", RSA_NO_PADDING);
  lua_set_key_INT(L, "RSA_PKCS1_PADDING", RSA_PKCS1_PADDING);
  lua_set_key_INT(L, "RSA_PKCS1_OAEP_PADDING", RSA_PKCS1_OAEP_PADDING);

  /* 增加rsa_sign/rsa_verify算法常量*/
  lua_set_key_INT(L, "nid_md5", NID_md5);
  lua_set_key_INT(L, "nid_sha1", NID_sha1);
  lua_set_key_INT(L, "nid_sha256", NID_sha256);
  lua_set_key_INT(L, "nid_sha512", NID_sha512);

  /* 增加EVP的摘要方法模型  */
  lua_set_key_PTR(L, "EVP_md5", EVP_md5());
  // lua_set_key_PTR(L, "EVP_blake256", EVP_blake2s256());
  // lua_set_key_PTR(L, "EVP_blake512", EVP_blake2b512());
  lua_set_key_PTR(L, "EVP_sha128", EVP_sha1());
  lua_set_key_PTR(L, "EVP_sha224", EVP_sha224());
  lua_set_key_PTR(L, "EVP_sha256", EVP_sha256());
  lua_set_key_PTR(L, "EVP_sha384", EVP_sha384());
  lua_set_key_PTR(L, "EVP_sha512", EVP_sha512());
  return 1;
}


LUAMOD_API int luaopen_lcrypt(lua_State *L) {
  luaL_checkversion(L);
  luaL_Reg lcrypt[] = {
    { "uuid", luuid },
    { "guid", lguid },
    { "hashkey", lhashkey },
    { "randomkey", lrandomkey },
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
    { "md4", lmd4 },
    { "md5", lmd5 },
    { "crc32", lcrc32 },
    { "crc64", lcrc64 },
    { "adler32", ladler32 },
    { "sha1", lsha128 },
    { "sha128", lsha128 },
    { "sha224", lsha224 },
    { "sha256", lsha256 },
    { "sha384", lsha384 },
    { "sha512", lsha512 },
    { "ripemd160", lripemd160},
    // HMAC
    { "hmac_md4", lhmac_md4 },
    { "hmac_md5", lhmac_md5 },
    { "hmac_sha1", lhmac_sha128 },
    { "hmac_sha128", lhmac_sha128 },
    { "hmac_sha224", lhmac_sha224 },
    { "hmac_sha256", lhmac_sha256 },
    { "hmac_sha384", lhmac_sha384 },
    { "hmac_sha512", lhmac_sha512 },
    { "hmac_hash", lhmac_hash },
    { "hmac_ripemd160", lhmac_ripemd160},
    { "hmac_pbkdf2", lhmac_pbkdf2 },
    { "xor_str", lxor_str },
    // 公钥加密 -> 私钥解密
    { "rsa_public_key_encode", lrsa_public_key_encode },
    { "rsa_private_key_decode", lrsa_private_key_decode },
    // 私钥加密 -> 公钥解密
    { "rsa_private_key_encode", lrsa_private_key_encode },
    { "rsa_public_key_decode", lrsa_public_key_decode },
    //md5/sha128/sha256/sha512 with rsa
    {"rsa_sign", lrsa_sign},
    {"rsa_verify", lrsa_verify},
    // aes 加密
    { "aes_ecb_encrypt", laes_ecb_encrypt },
    { "aes_cbc_encrypt", laes_cbc_encrypt },
    { "aes_cfb_encrypt", laes_cfb_encrypt },
    { "aes_ofb_encrypt", laes_ofb_encrypt },
    { "aes_ctr_encrypt", laes_ctr_encrypt },
    { "aes_gcm_encrypt", laes_gcm_encrypt },
    // aes 解密
    { "aes_ecb_decrypt", laes_ecb_decrypt },
    { "aes_cbc_decrypt", laes_cbc_decrypt },
    { "aes_cfb_decrypt", laes_cfb_decrypt },
    { "aes_ofb_decrypt", laes_ofb_decrypt },
    { "aes_ctr_decrypt", laes_ctr_decrypt },
    { "aes_gcm_decrypt", laes_gcm_decrypt },
    { "rc4", lrc4 },
    // DES加密/解密
    { "desencode", ldesencode },
    { "desdecode", ldesdecode },
    { "des_encrypt", ldes_encrypt },
    { "des_decrypt", ldes_decrypt },
    // SM2/SM3/SM4 国密
    { "sm3", lsm3 },
    { "hmac_sm3", lhmac_sm3 },
    { "sm2keygen", lsm2keygen },
    { "sm2sign", lsm2sign },
    { "sm2verify", lsm2verify },
    { "sm4_cbc_encrypt", lsm4_cbc_encrypt },
    { "sm4_cbc_decrypt", lsm4_cbc_decrypt },
    { "sm4_ecb_encrypt", lsm4_ecb_encrypt },
    { "sm4_ecb_decrypt", lsm4_ecb_decrypt },
    { "sm4_ofb_encrypt", lsm4_ofb_encrypt },
    { "sm4_ofb_decrypt", lsm4_ofb_decrypt },
    { "sm4_ctr_encrypt", lsm4_ctr_encrypt },
    { "sm4_ctr_decrypt", lsm4_ctr_decrypt },
    { NULL, NULL },
  };
  luaL_newlib(L, lcrypt);
  return crypt_set_key_value(L);
}
