#include "lcrypt.h"
#include <openssl/err.h>

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
  size_t text_size = -1;
  const uint8_t* text = (const uint8_t*)luaL_checklstring(L, 1, &text_size);
  if (!text || text_size < 1)
    return NULL;

  *size = text_size;
  return text;
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

  if (0 > RSA_public_encrypt(text_size, text, result, key, RSA_PKCS1_PADDING)) {
    RSA_free(key);
    luaL_pushresultsize(&b, 0);
    return luaL_error(L, "encrypt text falied.");
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
    return luaL_error(L, "Can't find public key or Invalid public key");

  luaL_Buffer b;
  unsigned char* result = (unsigned char*)luaL_buffinitsize(L, &b, RSA_size(key));

  size_t len = RSA_private_decrypt(text_size, text, result, key, RSA_PKCS1_PADDING);
  if (0 > len) {
    RSA_free(key);
    luaL_pushresultsize(&b, 0);
    return luaL_error(L, "encrypt text falied.");
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
    return luaL_error(L, "Can't find public key or Invalid public key");

  luaL_Buffer b;
  unsigned char* result = (unsigned char*)luaL_buffinitsize(L, &b, RSA_size(key));

  if (0 > RSA_private_encrypt(text_size, text, result, key, RSA_PKCS1_PADDING)) {
    RSA_free(key);
    luaL_pushresultsize(&b, 0);
    return luaL_error(L, "encrypt text falied.");
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

  size_t len = RSA_public_decrypt(text_size, text, result, key, RSA_PKCS1_PADDING);
  if (0 > len) {
    RSA_free(key);
    luaL_pushresultsize(&b, 0);
    return luaL_error(L, "encrypt text falied.");
  }

  luaL_pushresultsize(&b, len);

  RSA_free(key);

  return 1;
}