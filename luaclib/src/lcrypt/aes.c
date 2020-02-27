#include "lcrypt.h"

#define aes_bit_to_ecb_evp(bit) (bit == 16 ? EVP_aes_128_ecb() : bit == 24 ? EVP_aes_192_ecb() : EVP_aes_256_ecb())

#define aes_bit_to_cbc_evp(bit) (bit == 16 ? EVP_aes_128_cbc() : bit == 24 ? EVP_aes_192_cbc() : EVP_aes_256_cbc())

#define aes_bit_to_cfb_evp(bit) (bit == 16 ? EVP_aes_128_cfb() : bit == 24 ? EVP_aes_192_cfb() : EVP_aes_256_cfb())

#define aes_bit_to_ofb_evp(bit) (bit == 16 ? EVP_aes_128_ofb() : bit == 24 ? EVP_aes_192_ofb() : EVP_aes_256_ofb())

#define aes_bit_to_ctr_evp(bit) (bit == 16 ? EVP_aes_128_ctr() : bit == 24 ? EVP_aes_192_ctr() : EVP_aes_256_ctr())

/* ------ 以下为aes加密函数 ------  */

int laes_ecb_encrypt(lua_State *L) {
  lua_Integer bit = luaL_checkinteger(L, 1);
  if (bit != 16 && bit != 24 && bit != 32)
    return luaL_error(L, "Invalid bit");

  const uint8_t* key = (const uint8_t*)luaL_checkstring(L, 2);
  if (!key)
    return luaL_error(L, "Invalid key");

  size_t text_sz = 0;
  const uint8_t* text = (const uint8_t*)luaL_checklstring(L, 3, &text_sz);
  if (!text)
    return luaL_error(L, "Invalid text");

  const uint8_t* iv = (const uint8_t*)luaL_checkstring(L, 4);
  if (!iv)
    return luaL_error(L, "Invalid iv");

  EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
  if (!ctx)
    return luaL_error(L, "allocate EVP failed.");

  if (1 != EVP_EncryptInit_ex(ctx, aes_bit_to_ecb_evp(bit), NULL, key, iv)){
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    return luaL_error(L, "aes_init failed.");
  }

  luaL_Buffer b;
  size_t out_len = text_sz * 2;
  size_t resuilt_len = 0;
  unsigned char *out = (unsigned char *)luaL_buffinitsize(L, &b, text_sz * 2);
  
  int buffer_len = out_len;
  if (0 == EVP_EncryptUpdate(ctx, out, &buffer_len, text, text_sz)) {
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    luaL_pushresultsize(&b, 0);
    return luaL_error(L, "aes_update failed.");
  }
  resuilt_len += buffer_len;

  int final_len = resuilt_len;
  if (0 == EVP_EncryptFinal_ex(ctx, out + final_len, &final_len)) {
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    luaL_pushresultsize(&b, 0);
    return luaL_error(L, "aes_final failed.");
  }
  resuilt_len += final_len;

  luaL_pushresultsize(&b, resuilt_len);

  EVP_CIPHER_CTX_cleanup(ctx);
  EVP_CIPHER_CTX_free(ctx);
  return 1;
}

int laes_cbc_encrypt(lua_State *L) {
  lua_Integer bit = luaL_checkinteger(L, 1);
  if (bit != 16 && bit != 24 && bit != 32)
    return luaL_error(L, "Invalid bit");

  const uint8_t* key = (const uint8_t*)luaL_checkstring(L, 2);
  if (!key)
    return luaL_error(L, "Invalid key");

  size_t text_sz = 0;
  const uint8_t* text = (const uint8_t*)luaL_checklstring(L, 3, &text_sz);
  if (!text)
    return luaL_error(L, "Invalid text");

  const uint8_t* iv = (const uint8_t*)luaL_checkstring(L, 4);
  if (!iv)
    return luaL_error(L, "Invalid iv");

  EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
  if (!ctx)
    return luaL_error(L, "allocate EVP failed.");

  if (1 != EVP_EncryptInit_ex(ctx, aes_bit_to_cbc_evp(bit), NULL, key, iv)){
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    return luaL_error(L, "aes_init failed.");
  }

  luaL_Buffer b;
  size_t out_len = text_sz * 2;
  size_t resuilt_len = 0;
  unsigned char *out = (unsigned char *)luaL_buffinitsize(L, &b, text_sz * 2);
  
  int buffer_len = out_len;
  if (0 == EVP_EncryptUpdate(ctx, out, &buffer_len, text, text_sz)) {
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    luaL_pushresultsize(&b, 0);
    return luaL_error(L, "aes_update failed.");
  }
  resuilt_len += buffer_len;

  int final_len = resuilt_len;
  if (0 == EVP_EncryptFinal_ex(ctx, out + final_len, &final_len)) {
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    luaL_pushresultsize(&b, 0);
    return luaL_error(L, "aes_final failed.");
  }
  resuilt_len += final_len;

  luaL_pushresultsize(&b, resuilt_len);

  // printf("ENC: 需要%d长度的iv[%d], 实际长度为:%lu\n", EVP_CIPHER_iv_length(aes_bit_to_cbc_evp(bit)), bit, strlen(iv));

  EVP_CIPHER_CTX_cleanup(ctx);
  EVP_CIPHER_CTX_free(ctx);
  return 1;
}

/* 

int laes_cfb_encrypt(lua_State *L) {
  lua_Integer bit = luaL_checkinteger(L, 1);
  if (bit != 16 && bit != 24 && bit != 32)
    return luaL_error(L, "Invalid bit");

  const uint8_t* key = (const uint8_t*)luaL_checkstring(L, 2);
  if (!key)
    return luaL_error(L, "Invalid key");

  size_t text_sz = 0;
  const uint8_t* text = (const uint8_t*)luaL_checklstring(L, 3, &text_sz);
  if (!text)
    return luaL_error(L, "Invalid text");

  const uint8_t* iv = (const uint8_t*)luaL_checkstring(L, 4);
  if (!iv)
    return luaL_error(L, "Invalid iv");

  EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
  if (!ctx)
    return luaL_error(L, "allocate EVP failed.");

  if (1 != EVP_EncryptInit_ex(ctx, aes_bit_to_cfb_evp(bit), NULL, key, iv)){
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    return luaL_error(L, "aes_init failed.");
  }

  luaL_Buffer b;
  size_t out_len = text_sz * 2;
  size_t resuilt_len = 0;
  unsigned char *out = (unsigned char *)luaL_buffinitsize(L, &b, text_sz * 2);
  
  int buffer_len = out_len;
  if (0 == EVP_EncryptUpdate(ctx, out, &buffer_len, text, text_sz)) {
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    luaL_pushresultsize(&b, 0);
    return luaL_error(L, "aes_update failed.");
  }
  resuilt_len += buffer_len;

  int final_len = resuilt_len;
  if (0 == EVP_EncryptFinal_ex(ctx, out + final_len, &final_len)) {
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    luaL_pushresultsize(&b, 0);
    return luaL_error(L, "aes_final failed.");
  }
  resuilt_len += final_len;

  luaL_pushresultsize(&b, resuilt_len);

  EVP_CIPHER_CTX_cleanup(ctx);
  EVP_CIPHER_CTX_free(ctx);
  return 1;
}

int laes_ofb_encrypt(lua_State *L) {
  lua_Integer bit = luaL_checkinteger(L, 1);
  if (bit != 16 && bit != 24 && bit != 32)
    return luaL_error(L, "Invalid bit");

  const uint8_t* key = (const uint8_t*)luaL_checkstring(L, 2);
  if (!key)
    return luaL_error(L, "Invalid key");

  size_t text_sz = 0;
  const uint8_t* text = (const uint8_t*)luaL_checklstring(L, 3, &text_sz);
  if (!text)
    return luaL_error(L, "Invalid text");

  const uint8_t* iv = (const uint8_t*)luaL_checkstring(L, 4);
  if (!iv)
    return luaL_error(L, "Invalid iv");

  EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
  if (!ctx)
    return luaL_error(L, "allocate EVP failed.");

  if (1 != EVP_EncryptInit_ex(ctx, aes_bit_to_ofb_evp(bit), NULL, key, iv)){
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    return luaL_error(L, "aes_init failed.");
  }

  luaL_Buffer b;
  size_t out_len = text_sz * 2;
  size_t resuilt_len = 0;
  unsigned char *out = (unsigned char *)luaL_buffinitsize(L, &b, text_sz * 2);
  
  int buffer_len = out_len;
  if (0 == EVP_EncryptUpdate(ctx, out, &buffer_len, text, text_sz)) {
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    luaL_pushresultsize(&b, 0);
    return luaL_error(L, "aes_update failed.");
  }
  resuilt_len += buffer_len;

  int final_len = resuilt_len;
  if (0 == EVP_EncryptFinal_ex(ctx, out + final_len, &final_len)) {
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    luaL_pushresultsize(&b, 0);
    return luaL_error(L, "aes_final failed.");
  }
  resuilt_len += final_len;

  luaL_pushresultsize(&b, resuilt_len);

  EVP_CIPHER_CTX_cleanup(ctx);
  EVP_CIPHER_CTX_free(ctx);
  return 1;
}

int laes_ctr_encrypt(lua_State *L) {
  lua_Integer bit = luaL_checkinteger(L, 1);
  if (bit != 16 && bit != 24 && bit != 32)
    return luaL_error(L, "Invalid bit");

  const uint8_t* key = (const uint8_t*)luaL_checkstring(L, 2);
  if (!key)
    return luaL_error(L, "Invalid key");

  size_t text_sz = 0;
  const uint8_t* text = (const uint8_t*)luaL_checklstring(L, 3, &text_sz);
  if (!text)
    return luaL_error(L, "Invalid text");

  const uint8_t* iv = (const uint8_t*)luaL_checkstring(L, 4);
  if (!iv)
    return luaL_error(L, "Invalid iv");

  EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
  if (!ctx)
    return luaL_error(L, "allocate EVP failed.");

  if (1 != EVP_EncryptInit_ex(ctx, aes_bit_to_ctr_evp(bit), NULL, key, iv)){
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    return luaL_error(L, "aes_init failed.");
  }

  luaL_Buffer b;
  size_t out_len = text_sz * 2;
  size_t resuilt_len = 0;
  unsigned char *out = (unsigned char *)luaL_buffinitsize(L, &b, text_sz * 2);
  
  int buffer_len = out_len;
  if (0 == EVP_EncryptUpdate(ctx, out, &buffer_len, text, text_sz)) {
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    luaL_pushresultsize(&b, 0);
    return luaL_error(L, "aes_update failed.");
  }
  resuilt_len += buffer_len;

  int final_len = resuilt_len;
  if (0 == EVP_EncryptFinal_ex(ctx, out + final_len, &final_len)) {
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    luaL_pushresultsize(&b, 0);
    return luaL_error(L, "aes_final failed.");
  }
  resuilt_len += final_len;

  luaL_pushresultsize(&b, resuilt_len);

  EVP_CIPHER_CTX_cleanup(ctx);
  EVP_CIPHER_CTX_free(ctx);
  return 1;
}
*/

/* ------ 以下为aes解密函数 ------  */


int laes_ecb_decrypt(lua_State *L) {
  lua_Integer bit = luaL_checkinteger(L, 1);
  if (bit != 16 && bit != 24 && bit != 32)
    return luaL_error(L, "Invalid bit");

  const uint8_t* key = (const uint8_t*)luaL_checkstring(L, 2);
  if (!key)
    return luaL_error(L, "Invalid key");

  size_t text_sz = 0;
  const uint8_t* text = (const uint8_t*)luaL_checklstring(L, 3, &text_sz);
  if (!text)
    return luaL_error(L, "Invalid text");

  const uint8_t* iv = (const uint8_t*)luaL_checkstring(L, 4);
  if (!iv)
    return luaL_error(L, "Invalid iv");

  EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
  if (!ctx)
    return luaL_error(L, "allocate EVP failed.");

  if (1 != EVP_DecryptInit_ex(ctx, aes_bit_to_ecb_evp(bit), NULL, key, iv)){
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    return luaL_error(L, "aes_init failed.");
  }

  luaL_Buffer b;
  size_t out_len = text_sz * 2;
  size_t resuilt_len = 0;
  unsigned char *out = (unsigned char *)luaL_buffinitsize(L, &b, text_sz * 2);
  
  int buffer_len = out_len;
  if (0 == EVP_DecryptUpdate(ctx, out, &buffer_len, text, text_sz)) {
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    luaL_pushresultsize(&b, 0);
    return luaL_error(L, "aes_update failed.");
  }
  resuilt_len += buffer_len;

  int final_len = resuilt_len;
  if (0 == EVP_DecryptFinal_ex(ctx, out + final_len, &final_len)) {
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    luaL_pushresultsize(&b, 0);
    return luaL_error(L, "aes_final failed.");
  }
  resuilt_len += final_len;

  luaL_pushresultsize(&b, resuilt_len);

  EVP_CIPHER_CTX_cleanup(ctx);
  EVP_CIPHER_CTX_free(ctx);
  return 1;
}

int laes_cbc_decrypt(lua_State *L) {
  lua_Integer bit = luaL_checkinteger(L, 1);
  if (bit != 16 && bit != 24 && bit != 32)
    return luaL_error(L, "Invalid bit");

  const uint8_t* key = (const uint8_t*)luaL_checkstring(L, 2);
  if (!key)
    return luaL_error(L, "Invalid key");

  size_t text_sz = 0;
  const uint8_t* text = (const uint8_t*)luaL_checklstring(L, 3, &text_sz);
  if (!text)
    return luaL_error(L, "Invalid text");

  const uint8_t* iv = (const uint8_t*)luaL_checkstring(L, 4);
  if (!iv)
    return luaL_error(L, "Invalid iv");

  EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
  if (!ctx)
    return luaL_error(L, "allocate EVP failed.");

  if (1 != EVP_DecryptInit_ex(ctx, aes_bit_to_cbc_evp(bit), NULL, key, iv)){
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    return luaL_error(L, "aes_init failed.");
  }

  EVP_CIPHER_CTX_set_key_length(ctx, bit);

  luaL_Buffer b;
  size_t out_len = text_sz * 2;
  size_t resuilt_len = 0;
  unsigned char *out = (unsigned char *)luaL_buffinitsize(L, &b, text_sz * 2);
  
  int buffer_len = out_len;
  if (0 == EVP_DecryptUpdate(ctx, out, &buffer_len, text, text_sz)) {
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    luaL_pushresultsize(&b, 0);
    return luaL_error(L, "aes_update failed.");
  }
  resuilt_len += buffer_len;

  int final_len = resuilt_len;
  if (0 == EVP_DecryptFinal_ex(ctx, out + final_len, &final_len)) {
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    luaL_pushresultsize(&b, 0);
    return luaL_error(L, "aes_final failed.");
  }
  resuilt_len += final_len;

  luaL_pushresultsize(&b, resuilt_len);

  // printf("DEC: 需要%d长度的iv[%d], 实际长度为:%lu\n", EVP_CIPHER_iv_length(aes_bit_to_cbc_evp(bit)), bit, strlen(iv));

  EVP_CIPHER_CTX_cleanup(ctx);
  EVP_CIPHER_CTX_free(ctx);
  return 1;
}

/*
int laes_cfb_decrypt(lua_State *L) {
  lua_Integer bit = luaL_checkinteger(L, 1);
  if (bit != 16 && bit != 24 && bit != 32)
    return luaL_error(L, "Invalid bit");

  const uint8_t* key = (const uint8_t*)luaL_checkstring(L, 2);
  if (!key)
    return luaL_error(L, "Invalid key");

  size_t text_sz = 0;
  const uint8_t* text = (const uint8_t*)luaL_checklstring(L, 3, &text_sz);
  if (!text)
    return luaL_error(L, "Invalid text");

  const uint8_t* iv = (const uint8_t*)luaL_checkstring(L, 4);
  if (!iv)
    return luaL_error(L, "Invalid iv");

  EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
  if (!ctx)
    return luaL_error(L, "allocate EVP failed.");

  if (1 != EVP_DecryptInit_ex(ctx, aes_bit_to_cfb_evp(bit), NULL, key, iv)){
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    return luaL_error(L, "aes_init failed.");
  }

  luaL_Buffer b;
  size_t out_len = text_sz * 2;
  size_t resuilt_len = 0;
  unsigned char *out = (unsigned char *)luaL_buffinitsize(L, &b, text_sz * 2);
  
  int buffer_len = out_len;
  if (0 == EVP_DecryptUpdate(ctx, out, &buffer_len, text, text_sz)) {
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    luaL_pushresultsize(&b, 0);
    return luaL_error(L, "aes_update failed.");
  }
  resuilt_len += buffer_len;

  int final_len = resuilt_len;
  if (0 == EVP_DecryptFinal_ex(ctx, out + final_len, &final_len)) {
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    luaL_pushresultsize(&b, 0);
    return luaL_error(L, "aes_final failed.");
  }
  resuilt_len += final_len;

  luaL_pushresultsize(&b, resuilt_len);

  EVP_CIPHER_CTX_cleanup(ctx);
  EVP_CIPHER_CTX_free(ctx);
  return 1;
}

int laes_ofb_decrypt(lua_State *L) {
  lua_Integer bit = luaL_checkinteger(L, 1);
  if (bit != 16 && bit != 24 && bit != 32)
    return luaL_error(L, "Invalid bit");

  const uint8_t* key = (const uint8_t*)luaL_checkstring(L, 2);
  if (!key)
    return luaL_error(L, "Invalid key");

  size_t text_sz = 0;
  const uint8_t* text = (const uint8_t*)luaL_checklstring(L, 3, &text_sz);
  if (!text)
    return luaL_error(L, "Invalid text");

  const uint8_t* iv = (const uint8_t*)luaL_checkstring(L, 4);
  if (!iv)
    return luaL_error(L, "Invalid iv");

  EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
  if (!ctx)
    return luaL_error(L, "allocate EVP failed.");

  if (1 != EVP_DecryptInit_ex(ctx, aes_bit_to_ofb_evp(bit), NULL, key, iv)){
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    return luaL_error(L, "aes_init failed.");
  }

  luaL_Buffer b;
  size_t out_len = text_sz * 2;
  size_t resuilt_len = 0;
  unsigned char *out = (unsigned char *)luaL_buffinitsize(L, &b, text_sz * 2);
  
  int buffer_len = out_len;
  if (0 == EVP_DecryptUpdate(ctx, out, &buffer_len, text, text_sz)) {
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    luaL_pushresultsize(&b, 0);
    return luaL_error(L, "aes_update failed.");
  }
  resuilt_len += buffer_len;

  int final_len = resuilt_len;
  if (0 == EVP_DecryptFinal_ex(ctx, out + final_len, &final_len)) {
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    luaL_pushresultsize(&b, 0);
    return luaL_error(L, "aes_final failed.");
  }
  resuilt_len += final_len;

  luaL_pushresultsize(&b, resuilt_len);

  EVP_CIPHER_CTX_cleanup(ctx);
  EVP_CIPHER_CTX_free(ctx);
  return 1;
}

int laes_ctr_decrypt(lua_State *L) {
  lua_Integer bit = luaL_checkinteger(L, 1);
  if (bit != 16 && bit != 24 && bit != 32)
    return luaL_error(L, "Invalid bit");

  const uint8_t* key = (const uint8_t*)luaL_checkstring(L, 2);
  if (!key)
    return luaL_error(L, "Invalid key");

  size_t text_sz = 0;
  const uint8_t* text = (const uint8_t*)luaL_checklstring(L, 3, &text_sz);
  if (!text)
    return luaL_error(L, "Invalid text");

  const uint8_t* iv = (const uint8_t*)luaL_checkstring(L, 4);
  if (!iv)
    return luaL_error(L, "Invalid iv");

  EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
  if (!ctx)
    return luaL_error(L, "allocate EVP failed.");

  if (1 != EVP_DecryptInit_ex(ctx, aes_bit_to_ctr_evp(bit), NULL, key, iv)){
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    return luaL_error(L, "aes_init failed.");
  }

  luaL_Buffer b;
  size_t out_len = text_sz * 2;
  size_t resuilt_len = 0;
  unsigned char *out = (unsigned char *)luaL_buffinitsize(L, &b, text_sz * 2);
  
  int buffer_len = out_len;
  if (0 == EVP_DecryptUpdate(ctx, out, &buffer_len, text, text_sz)) {
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    luaL_pushresultsize(&b, 0);
    return luaL_error(L, "aes_update failed.");
  }
  resuilt_len += buffer_len;

  int final_len = resuilt_len;
  if (0 == EVP_DecryptFinal_ex(ctx, out + final_len, &final_len)) {
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    luaL_pushresultsize(&b, 0);
    return luaL_error(L, "aes_final failed.");
  }
  resuilt_len += final_len;

  luaL_pushresultsize(&b, resuilt_len);

  EVP_CIPHER_CTX_cleanup(ctx);
  EVP_CIPHER_CTX_free(ctx);
  return 1;
}
*/