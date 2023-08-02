#include "lcrypt.h"

static inline EVP_PKEY* new_public_key(lua_State *L) {
  size_t p_size = 0;
  const uint8_t* path = (const uint8_t*)luaL_checklstring(L, 2, &p_size);
  if (!path || p_size <= 0)
    return NULL;

  EVP_PKEY* key;
  /* 读字符串 */
  BIO* IO = BIO_new(BIO_s_mem()); BIO_write(IO, (const char *)path, p_size);
  key = PEM_read_bio_PUBKEY(IO, NULL, NULL, NULL);
  BIO_free(IO);
  if (key)
    return key;
  /* 读文件 */
  FILE* f = fopen((const char *)path, "rb");
  if (!f)
    return NULL;

  key = PEM_read_PUBKEY(f, NULL, NULL, NULL);
  fclose(f);
  return key;
}

static inline EVP_PKEY* new_private_key(lua_State *L) {
  size_t p_size = 0;
  const uint8_t* path = (const uint8_t*)luaL_checklstring(L, 2, &p_size);
  if (!path || p_size <= 0)
    return NULL;

  EVP_PKEY * key;
  /* 读字符串 */
  BIO* IO = BIO_new(BIO_s_mem()); BIO_write(IO, (const char *)path, p_size);
  key = PEM_read_bio_PrivateKey(IO, NULL, NULL, NULL);
  BIO_free(IO);
  if (key)
    return key;
  /* 读文件 */
  FILE* f = fopen((const char *)path, "rb");
  if (!f)
    return NULL;

  key = PEM_read_PrivateKey(f, NULL, NULL, NULL);
  fclose(f);
  return key;
}

static inline int rsa_encrypt(lua_State *L, EVP_PKEY *rsa, int padding, const uint8_t *text, size_t tsize) {
  size_t outlen;
  EVP_PKEY_CTX *ctx = EVP_PKEY_CTX_new(rsa, NULL);
  if (
    EVP_PKEY_encrypt_init(ctx) <= 0 ||
    EVP_PKEY_CTX_set_rsa_padding(ctx, padding) <= 0 ||
    EVP_PKEY_encrypt(ctx, NULL, &outlen, text, tsize) <= 0
  ) {
    EVP_PKEY_CTX_free(ctx); EVP_PKEY_free(rsa);
    lua_pushboolean(L, 0);
    lua_pushliteral(L, "[rsa error]: rsa encrypt init failed.");
    return 2;
  }
  // xrio_log("enc outlen = %zu\n", outlen);
  unsigned char *out = lua_newuserdata(L, outlen);
  int ret = EVP_PKEY_encrypt(ctx, out, &outlen, text, tsize);
  if (ret <= 0) {
    EVP_PKEY_CTX_free(ctx); EVP_PKEY_free(rsa);
    return luaL_error(L, "[rsa error]: rsa encrypt finally failed. %d", ret);
  }

  lua_pushlstring(L, (char*)out, outlen);
  EVP_PKEY_CTX_free(ctx);
  EVP_PKEY_free(rsa);
  return 1;
}

static inline int rsa_decrypt(lua_State *L, EVP_PKEY *rsa, int padding, const uint8_t *cipher, size_t csize) {
  size_t outlen;
  EVP_PKEY_CTX *ctx = EVP_PKEY_CTX_new(rsa, NULL);
  if (
    EVP_PKEY_decrypt_init(ctx) <= 0 ||
    EVP_PKEY_CTX_set_rsa_padding(ctx, padding) <= 0 ||
    EVP_PKEY_decrypt(ctx, NULL, &outlen, cipher, csize) <= 0
  ) {
    EVP_PKEY_CTX_free(ctx); EVP_PKEY_free(rsa);
    lua_pushboolean(L, 0);
    lua_pushliteral(L, "[rsa error]: rsa decrypt init failed.");
    return 2;
  }
  // xrio_log("dec outlen = %zu\n", outlen);
  unsigned char *out = lua_newuserdata(L, outlen);
  int ret = EVP_PKEY_decrypt(ctx, out, &outlen, cipher, csize);
  if (ret <= 0) {
    EVP_PKEY_CTX_free(ctx); EVP_PKEY_free(rsa);
    return luaL_error(L, "[rsa error]: rsa decrypt finally failed. %d", ret);
  }
  lua_pushlstring(L, (char*)out, outlen);
  EVP_PKEY_CTX_free(ctx);
  EVP_PKEY_free(rsa);
  return 1;
}

int lrsa_public_key_encode(lua_State *L) {
  size_t tsize = 0;
  const uint8_t* text = (const uint8_t*)luaL_checklstring(L, 1, &tsize);
  if (!text || tsize < 1)
    return luaL_error(L, "[rsa error]: Invalid text");

  EVP_PKEY *rsa = new_public_key(L);
  if (!rsa)
    return luaL_error(L, "[rsa error]: Can't load rsa public key.");

  return rsa_encrypt(L, rsa, luaL_checkinteger(L, 3), text, tsize);
}

int lrsa_public_key_decode(lua_State *L) {
  size_t csize = 0;
  const uint8_t* cipher = (const uint8_t*)luaL_checklstring(L, 1, &csize);
  if (!cipher || csize < 1)
    return luaL_error(L, "[rsa error]: Invalid cipher");

  EVP_PKEY *rsa = new_public_key(L);
  if (!rsa)
    return luaL_error(L, "[rsa error]: Can't load rsa public key.");

  return rsa_decrypt(L, rsa, luaL_checkinteger(L, 3), cipher, csize);
}

int lrsa_private_key_encode(lua_State *L) {
  size_t tsize = 0;
  const uint8_t* text = (const uint8_t*)luaL_checklstring(L, 1, &tsize);
  if (!text || tsize < 1)
    return luaL_error(L, "[rsa error]: Invalid text");

  EVP_PKEY *rsa = new_private_key(L);
  if (!rsa)
    return luaL_error(L, "[rsa error]: Can't load rsa private key.");

  return rsa_encrypt(L, rsa, luaL_checkinteger(L, 3), text, tsize);
}

int lrsa_private_key_decode(lua_State *L) {
  size_t csize = 0;
  const uint8_t* cipher = (const uint8_t*)luaL_checklstring(L, 1, &csize);
  if (!cipher || csize < 1)
    return luaL_error(L, "[rsa error]: Invalid cipher");

  EVP_PKEY *rsa = new_private_key(L);
  if (!rsa)
    return luaL_error(L, "[rsa error]: Can't load rsa private key.");

  return rsa_decrypt(L, rsa, luaL_checkinteger(L, 3), cipher, csize);
}

// 获取签名方法
#define rsa_nid_mode(L, pos) EVP_get_digestbynid(lua_tointeger((L), (pos)))

// RSA签名算法
int lrsa_sign(lua_State *L) {
  size_t tsize = 0;
  const uint8_t* text = (const uint8_t*)luaL_checklstring(L, 1, &tsize);
  if (!text || tsize < 1)
    return luaL_error(L, "[rsa sign]: Invalid text");

  EVP_PKEY *rsa = new_private_key(L);
  if (!rsa)
    return luaL_error(L, "[rsa sign]: Can't find valide private rsa.");

  size_t siglen;
  EVP_MD_CTX* ctx = EVP_MD_CTX_create();
  EVP_MD_CTX_init(ctx);

  if (
    EVP_DigestSignInit(ctx, NULL, rsa_nid_mode(L, 3), NULL, rsa) <= 0 ||
    EVP_DigestSignUpdate(ctx, text, tsize) <= 0 ||
    EVP_DigestSignFinal(ctx, NULL, &siglen) <= 0
    ) {
    EVP_MD_CTX_destroy(ctx); EVP_PKEY_free(rsa);
    return luaL_error(L, "[rsa sign]: init failed.");
  }

  char sig[siglen];
  if (EVP_DigestSignFinal(ctx, (unsigned char *)sig, &siglen) <= 0) {
    EVP_MD_CTX_destroy(ctx); EVP_PKEY_free(rsa);
    return luaL_error(L, "[rsa sign]: finally failed.");
  }

  lua_pushlstring(L, sig, siglen);
  EVP_MD_CTX_destroy(ctx);
  EVP_PKEY_free(rsa);
  return 1;
}

// RSA验签算法
int lrsa_verify(lua_State *L) {
  size_t tsize = 0;
  const uint8_t* text = (const uint8_t*)luaL_checklstring(L, 1, &tsize);
  if (!text || tsize < 1)
    return luaL_error(L, "[rsa verify]: Invalid text");

  size_t siglen = 0;
  const uint8_t *sig = (const uint8_t*)luaL_checklstring(L, 3, &siglen);
  if (!sig || siglen < 1)
    return luaL_error(L, "[rsa verify]: Invalid sign");

  EVP_PKEY* rsa = new_public_key(L);
  if (!rsa)
    return luaL_error(L, "[rsa verify]: Can't find valide public rsa.");

  EVP_MD_CTX* ctx = EVP_MD_CTX_create();
  EVP_MD_CTX_init(ctx);

  if (
    EVP_DigestVerifyInit(ctx, NULL, rsa_nid_mode(L, 4), NULL, rsa) <= 0 ||
    EVP_DigestVerifyUpdate(ctx, text, tsize) <= 0 ||
    EVP_DigestVerifyFinal(ctx, sig, siglen) <= 0
  )
    lua_pushboolean(L, 0);
  else
    lua_pushboolean(L, 1);

  EVP_MD_CTX_destroy(ctx);
  EVP_PKEY_free(rsa);
  return 1;
}