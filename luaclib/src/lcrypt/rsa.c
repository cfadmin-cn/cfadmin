#include "lcrypt.h"
// #include <openssl/err.h>

static inline RSA* READ_PEM_PUB_KEY(FILE *f) {
  RSA *key = NULL ;
  key = PEM_read_RSA_PUBKEY(f, NULL, NULL, NULL);
  if (key)
    return key;
  return PEM_read_RSAPublicKey(f, NULL, NULL, NULL);
}

static inline RSA* READ_PEM_PRI_KEY(FILE *f) {
  return PEM_read_RSAPrivateKey(f, NULL, NULL, NULL);
}

static inline RSA* new_public_key(lua_State *L) {
  size_t p_size = 0;
  const uint8_t* p_path = (const uint8_t*)luaL_checklstring(L, 2, &p_size);
  if (!p_path || p_size <= 0)
    return NULL;

  FILE* f = fopen((const char *)p_path, "rb");
  if (!f)
    return NULL;

  RSA* p_key = READ_PEM_PUB_KEY(f);
  if (!p_key){
    fclose(f);
    return NULL;
  }

  // RSA_print_fp(f, p_key, 0);
  // fflush(stdout);
  fclose(f);
  return p_key;
}

static inline RSA* new_private_key(lua_State *L) {
  size_t p_size = 0;
  const uint8_t* p_path = (const uint8_t*)luaL_checklstring(L, 2, &p_size);
  if (!p_path || p_size <= 0)
    return NULL;

  FILE* f = fopen((const char *)p_path, "rb");
  if (!f)
    return NULL;

  RSA* p_key = READ_PEM_PRI_KEY(f);
  if (!p_key){
    fclose(f);
    return NULL;
  }

  // RSA_print_fp(f, p_key, 0);
  // fflush(stdout);
  fclose(f);
  return p_key;
}

static inline const uint8_t* get_text(lua_State *L, size_t *size) {
  size_t tsize = 0;
  const uint8_t* text = (const uint8_t*)luaL_checklstring(L, 1, &tsize);
  if (!text || tsize < 1)
    return NULL;
  *size = tsize;
  return text;
}

static inline int get_mode(lua_State *L) {
  // 手动设置填充方式
  int isnum = 0;
  lua_Integer mode = lua_tointegerx(L, 3, &isnum);
  if (!isnum || (mode != RSA_NO_PADDING && mode != RSA_PKCS1_OAEP_PADDING))
    mode = RSA_PKCS1_PADDING;
  return mode;
}

int lrsa_public_key_encode(lua_State *L){

  size_t text_size = 0;
  const uint8_t* text = get_text(L, &text_size);
  if (!text || text_size < 1)
    return luaL_error(L, "Invalid text");

  RSA* key = new_public_key(L);
  if (!key)
    return luaL_error(L, "Can't find public key or Invalid public key");

  luaL_Buffer b;
  unsigned char* result = (unsigned char*)luaL_buffinitsize(L, &b, RSA_size(key));

  if (0 > RSA_public_encrypt(text_size, text, result, key, get_mode(L))) {
    RSA_free(key);
    luaL_pushresultsize(&b, 0);
    return luaL_error(L, "public_key_encode text falied.");
  }

  luaL_pushresultsize(&b, RSA_size(key));

  RSA_free(key);
  return 1;

}

int lrsa_private_key_decode(lua_State *L) {

  size_t text_size = 0;
  const uint8_t* text = get_text(L, &text_size);
  if (!text || text_size < 1)
    return luaL_error(L, "Invalid text");

  RSA* key = new_private_key(L);
  if (!key)
    return luaL_error(L, "Can't find private key or Invalid private key");

  luaL_Buffer b;
  unsigned char* result = (unsigned char*)luaL_buffinitsize(L, &b, RSA_size(key));

  size_t len = RSA_private_decrypt(text_size, text, result, key, get_mode(L));
  if (0 > len) {
    RSA_free(key);
    luaL_pushresultsize(&b, 0);
    return luaL_error(L, "private_key_decode text falied.");
  }

  luaL_pushresultsize(&b, len);

  RSA_free(key);

  return 1;

}

int lrsa_private_key_encode(lua_State *L){

  size_t text_size = 0;
  const uint8_t* text = get_text(L, &text_size);
  if (!text || text_size < 1)
    return luaL_error(L, "Invalid text");

  RSA* key = new_private_key(L);
  if (!key)
    return luaL_error(L, "Can't find private key or Invalid private key");

  luaL_Buffer b;
  unsigned char* result = (unsigned char*)luaL_buffinitsize(L, &b, RSA_size(key));

  if (0 > RSA_private_encrypt(text_size, text, result, key, get_mode(L))) {
    RSA_free(key);
    luaL_pushresultsize(&b, 0);
    return luaL_error(L, "private_key_encode text falied.");
  }

  luaL_pushresultsize(&b, RSA_size(key));

  RSA_free(key);

  return 1;
}

int lrsa_public_key_decode(lua_State *L){
  size_t text_size = 0;
  const uint8_t* text = get_text(L, &text_size);
  if (!text || text_size < 1)
    return luaL_error(L, "Invalid text");

  RSA* key = new_public_key(L);
  if (!key)
    return luaL_error(L, "Can't find public key or Invalid public key");

  luaL_Buffer b;
  unsigned char* result = (unsigned char*)luaL_buffinitsize(L, &b, RSA_size(key));

  size_t len = RSA_public_decrypt(text_size, text, result, key, get_mode(L));
  if (0 > len) {
    RSA_free(key);
    luaL_pushresultsize(&b, 0);
    return luaL_error(L, "public_key_decode text falied.");
  }

  luaL_pushresultsize(&b, len);

  RSA_free(key);

  return 1;
}


int lSha256WithRsa_sign(lua_State *L){

  size_t text_size = 0;
  const uint8_t* text = get_text(L, &text_size);
  if (!text || text_size < 1)
    return luaL_error(L, "Invalid text");

  RSA* rsa = new_private_key(L);
  if (!rsa)
    return luaL_error(L, "Can't find valide private rsa.");

  unsigned char sha_data[SHA256_DIGEST_LENGTH];
  SHA256((const unsigned char*) text, text_size, sha_data);

  luaL_Buffer b;
  unsigned char* result = (unsigned char*)luaL_buffinitsize(L, &b, RSA_size(rsa));
  uint32_t result_size = 0;

  if (1 != RSA_sign(NID_sha256, sha_data, SHA256_DIGEST_LENGTH, result, &result_size, rsa)) {
    RSA_free(rsa);
    return luaL_error(L, "computing result size failed.");
  }

  luaL_pushresultsize(&b, result_size);

  RSA_free(rsa);

  return 1;
}

int lSha256WithRsa_verify(lua_State *L){

  size_t text_size = 0;
  const uint8_t* text = get_text(L, &text_size);
  if (!text || text_size < 1)
    return luaL_error(L, "Invalid text");

  RSA* rsa = new_public_key(L);
  if (!rsa)
    return luaL_error(L, "Can't find valide private rsa.");

  size_t sign_size = 0;
  const uint8_t *sign = (const uint8_t*)luaL_checklstring(L, 3, &sign_size);
  if (!text || text_size < 1)
    return luaL_error(L, "Invalid text");

  unsigned char sha_data[SHA256_DIGEST_LENGTH];
  SHA256((const unsigned char*) text, text_size, sha_data);

  if (1 != RSA_verify(NID_sha256, sha_data, SHA256_DIGEST_LENGTH, sign, sign_size, rsa)) {
    RSA_free(rsa);
    return 0;
  }
  RSA_free(rsa);
  lua_pushboolean(L, 1);
  return 1;
}

int lSha128WithRsa_sign(lua_State *L){

  size_t text_size = 0;
  const uint8_t* text = get_text(L, &text_size);
  if (!text || text_size < 1)
    return luaL_error(L, "Invalid text");

  RSA* rsa = new_private_key(L);
  if (!rsa)
    return luaL_error(L, "Can't find valide private rsa.");

  unsigned char sha_data[SHA_DIGEST_LENGTH];
  SHA256((const unsigned char*) text, text_size, sha_data);

  luaL_Buffer b;
  unsigned char* result = (unsigned char*)luaL_buffinitsize(L, &b, RSA_size(rsa));
  uint32_t result_size = 0;

  if (1 != RSA_sign(NID_sha1, sha_data, SHA_DIGEST_LENGTH, result, &result_size, rsa)) {
    RSA_free(rsa);
    return luaL_error(L, "computing result size failed.");
  }

  luaL_pushresultsize(&b, result_size);

  RSA_free(rsa);

  return 1;
}

int lSha128WithRsa_verify(lua_State *L){

  size_t text_size = 0;
  const uint8_t* text = get_text(L, &text_size);
  if (!text || text_size < 1)
    return luaL_error(L, "Invalid text");

  RSA* rsa = new_public_key(L);
  if (!rsa)
    return luaL_error(L, "Can't find valide private rsa.");

  size_t sign_size = 0;
  const uint8_t *sign = (const uint8_t*)luaL_checklstring(L, 3, &sign_size);
  if (!text || text_size < 1)
    return luaL_error(L, "Invalid text");

  unsigned char sha_data[SHA_DIGEST_LENGTH];
  SHA256((const unsigned char*) text, text_size, sha_data);

  if (1 != RSA_verify(NID_sha1, sha_data, SHA_DIGEST_LENGTH, sign, sign_size, rsa)) {
    RSA_free(rsa);
    return 0;
  }
  RSA_free(rsa);
  lua_pushboolean(L, 1);
  return 1;
}