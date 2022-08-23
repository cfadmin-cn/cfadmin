#include "lcrypt.h"

#define AES_ECB_MODE (0)
#define AES_CBC_MODE (1)
#define AES_CFB_MODE (2)
#define AES_OFB_MODE (4)
#define AES_CTR_MODE (8)
#define AES_GCM_MODE (16)

#define aes_bit_to_ecb_evp(bit) (bit == 16 ? EVP_aes_128_ecb() : bit == 24 ? EVP_aes_192_ecb() : EVP_aes_256_ecb())

#define aes_bit_to_cbc_evp(bit) (bit == 16 ? EVP_aes_128_cbc() : bit == 24 ? EVP_aes_192_cbc() : EVP_aes_256_cbc())

#define aes_bit_to_cfb_evp(bit) (bit == 16 ? EVP_aes_128_cfb() : bit == 24 ? EVP_aes_192_cfb() : EVP_aes_256_cfb())

#define aes_bit_to_ofb_evp(bit) (bit == 16 ? EVP_aes_128_ofb() : bit == 24 ? EVP_aes_192_ofb() : EVP_aes_256_ofb())

#define aes_bit_to_ctr_evp(bit) (bit == 16 ? EVP_aes_128_ctr() : bit == 24 ? EVP_aes_192_ctr() : EVP_aes_256_ctr())

#define aes_bit_to_gcm_evp(bit) (bit == 16 ? EVP_aes_128_gcm() : bit == 24 ? EVP_aes_192_gcm() : EVP_aes_256_gcm())

static inline const EVP_CIPHER * aes_get_cipher(size_t mode, size_t bit) {
  switch(mode){
    case AES_ECB_MODE:
      return aes_bit_to_ecb_evp(bit);
    case AES_CBC_MODE:
      return aes_bit_to_cbc_evp(bit);
    case AES_CFB_MODE:
      return aes_bit_to_cfb_evp(bit);
    case AES_OFB_MODE:
      return aes_bit_to_ofb_evp(bit);
    case AES_CTR_MODE:
      return aes_bit_to_ctr_evp(bit);
    case AES_GCM_MODE:
      return aes_bit_to_gcm_evp(bit);
  }
  return NULL;
}

// 加密函数
static inline int do_aes_encrypt(lua_State *L, int bit, const uint8_t *key, const uint8_t *iv, const uint8_t *text, size_t tsize, size_t aes_mode) {

  EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
  if (!ctx)
    return luaL_error(L, "allocate EVP failed.");

  EVP_CIPHER_CTX_set_padding(ctx, 0);

  // EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, bit, NULL);

  if (1 != EVP_EncryptInit_ex(ctx, aes_get_cipher(aes_mode, bit), NULL, key, iv)){
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    lua_pushnil(L);
    lua_pushstring(L, "aes_encrypt_init failed.");
    return 2;
  }

  // printf("enc key len = %d\n", EVP_CIPHER_CTX_key_length(ctx));

  EVP_CIPHER_CTX_set_key_length(ctx, EVP_MAX_KEY_LENGTH);

  int out_size = tsize + EVP_MAX_BLOCK_LENGTH;
  uint8_t *out = lua_newuserdata(L, out_size);

  int update_len = out_size;
  if (0 == EVP_EncryptUpdate(ctx, out, &update_len, text, tsize)){
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    lua_pushnil(L);
    lua_pushstring(L, "aes_encrypt_update failed.");
    return 2;
  }

  int final_len = out_size;
  if (0 == EVP_EncryptFinal(ctx, out + update_len, &final_len)){
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    lua_pushnil(L);
    lua_pushstring(L, "aes_encrypt_final failed.");
    return 2;
  }

  lua_pushlstring(L, (const char*)out, update_len + final_len);
  EVP_CIPHER_CTX_cleanup(ctx);
  EVP_CIPHER_CTX_free(ctx);
  return 1;
}

// 解密函数
static inline int do_aes_decrypt(lua_State *L, int bit, const uint8_t *key, const uint8_t *iv, const uint8_t *cipher, size_t csize, size_t aes_mode) {

  EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
  if (!ctx)
    return luaL_error(L, "allocate EVP failed.");

  EVP_CIPHER_CTX_set_padding(ctx, 0);

  // EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, bit, NULL);

  if (1 != EVP_DecryptInit_ex(ctx, aes_get_cipher(aes_mode, bit), NULL, key, iv)){
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    lua_pushnil(L);
    lua_pushstring(L, "aes_decrypt_init failed.");
    return 2;
  }

  // printf("dec key len = %d\n", EVP_CIPHER_CTX_key_length(ctx));

  EVP_CIPHER_CTX_set_key_length(ctx, EVP_MAX_KEY_LENGTH);

  int out_size = csize + EVP_MAX_BLOCK_LENGTH;
  uint8_t *out = lua_newuserdata(L, out_size);

  int update_len = out_size;
  if (1 != EVP_DecryptUpdate(ctx, out, &update_len, cipher, csize)){
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    lua_pushnil(L);
    lua_pushstring(L, "aes_decrypt_update failed.");
    return 2;
  }

  int final_len = out_size;
  if (1 != EVP_DecryptFinal_ex(ctx, out + update_len, &final_len)){
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    lua_pushnil(L);
    lua_pushstring(L, "aes_decrypt_final failed.");
    return 2;
  }

  lua_pushlstring(L, (const char*)out, update_len + final_len);
  EVP_CIPHER_CTX_cleanup(ctx);
  EVP_CIPHER_CTX_free(ctx);
  return 1;
}


static inline int lua_getargs(lua_State *L, lua_Integer *bit, uint8_t **text, size_t *tsize, uint8_t **iv, uint8_t **key) {
  *bit = luaL_checkinteger(L, 1);
  if (*bit != 16 && *bit != 24 && *bit != 32)
    return luaL_error(L, "Invalid bit");

  *key = (uint8_t *)luaL_checkstring(L, 2);
  if (!key)
    return luaL_error(L, "Invalid key");

  size_t size = 0;
  *text = (uint8_t *)luaL_checklstring(L, 3, &size);
  if (!text)
    return luaL_error(L, "Invalid text");
  *tsize = size;

  *iv = (uint8_t *)luaL_checkstring(L, 4);
  if (!iv)
    return luaL_error(L, "Invalid iv");

  return 1;
}

static inline int AES_ENCRYPT(lua_State *L, int mode) {

  lua_Integer bit = 0; size_t text_sz = 0;

  uint8_t* iv = NULL; uint8_t* key = NULL; uint8_t* text = NULL;

  return lua_getargs(L, &bit, &text, &text_sz, &iv, &key) && do_aes_encrypt(L, bit, (const uint8_t*)key, (const uint8_t*)iv, (const uint8_t*)text, text_sz, mode);
}

static inline int AES_DECRYPT(lua_State *L, int mode) {

  lua_Integer bit = 0; size_t cipher_sz = 0;

  uint8_t* iv = NULL; uint8_t* key = NULL; uint8_t* cipher = NULL;

  return lua_getargs(L, &bit, &cipher, &cipher_sz, &iv, &key) && do_aes_decrypt(L, bit, (const uint8_t*)key, (const uint8_t*)iv, (const uint8_t*)cipher, cipher_sz, mode);
}

/* 加密封装 */

int laes_ecb_encrypt(lua_State *L) {

  return AES_ENCRYPT(L, AES_ECB_MODE);
}

int laes_cbc_encrypt(lua_State *L) {

  return AES_ENCRYPT(L, AES_CBC_MODE);
}

int laes_cfb_encrypt(lua_State *L) {

  return AES_ENCRYPT(L, AES_CFB_MODE);
}

int laes_ofb_encrypt(lua_State *L) {

  return AES_ENCRYPT(L, AES_OFB_MODE);
}

int laes_ctr_encrypt(lua_State *L) {

  return AES_ENCRYPT(L, AES_CTR_MODE);
}

/* 解密封装 */

int laes_ecb_decrypt(lua_State *L) {

  return AES_DECRYPT(L, AES_ECB_MODE);
}

int laes_cbc_decrypt(lua_State *L) {

  return AES_DECRYPT(L, AES_CBC_MODE);
}

int laes_cfb_decrypt(lua_State *L) {

  return AES_DECRYPT(L, AES_CFB_MODE);
}

int laes_ofb_decrypt(lua_State *L) {

  return AES_DECRYPT(L, AES_OFB_MODE);
}

int laes_ctr_decrypt(lua_State *L) {

  return AES_DECRYPT(L, AES_CTR_MODE);
}

/* AES GCM */
int laes_gcm_encrypt(lua_State *L) {

  lua_Integer bit = 0; size_t text_sz = 0;

  uint8_t* key = NULL; uint8_t* text = NULL; uint8_t* iv = NULL; 

  lua_getargs(L, &bit, &text, &text_sz, &iv, &key); uint8_t *aad = (uint8_t *)luaL_checkstring(L, 5); 

  EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
  if (!ctx)
    return luaL_error(L, "allocate EVP failed.");

  if (1 != EVP_EncryptInit_ex(ctx, aes_get_cipher(AES_GCM_MODE, bit), NULL, key, iv)){
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    lua_pushnil(L);
    lua_pushstring(L, "aes_encrypt_init failed.");
    return 2;
  }

  int out_size = text_sz + EVP_MAX_BLOCK_LENGTH;
  uint8_t *ciphertext = lua_newuserdata(L, out_size);

  int len;  int total = 0;

  /* 添加`aad` */
  if(1 != EVP_EncryptUpdate(ctx, NULL, &len, aad, strlen((char*)aad))) {
    EVP_CIPHER_CTX_free(ctx);
    lua_pushnil(L);
    lua_pushstring(L, "aes_encrypt_update update aad failed.");
    return 2;
  }
  // printf("len = %d", len);
  if(1 != EVP_EncryptUpdate(ctx, ciphertext, &len, text, text_sz)) {
    EVP_CIPHER_CTX_free(ctx);
    lua_pushnil(L);
    lua_pushstring(L, "aes_encrypt_update update cipher failed.");
    return 2;
  }
  total += len;

  if(1 != EVP_EncryptFinal_ex(ctx, ciphertext + len, &len)) {
    EVP_CIPHER_CTX_free(ctx);
    lua_pushnil(L);
    lua_pushstring(L, "aes_encrypt_final update aad failed.");
    return 2;
  }
  total += len;

  if(1 != EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_GET_TAG, 16, ciphertext + total)) {
    EVP_CIPHER_CTX_free(ctx);
    lua_pushnil(L);
    lua_pushstring(L, "aes_encrypt_final get tag failed.");
    return 2;
  }
  total += 16;

  lua_pushlstring(L, (const char*)ciphertext, total);
  EVP_CIPHER_CTX_free(ctx);
  return 1;
}

int laes_gcm_decrypt(lua_State *L) {
  lua_Integer bit = 0; size_t text_sz = 0;

  uint8_t* key = NULL; uint8_t* text = NULL; uint8_t* iv = NULL; 

  lua_getargs(L, &bit, &text, &text_sz, &iv, &key); uint8_t *aad = (uint8_t *)luaL_checkstring(L, 5); 

  EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
  if (!ctx)
    return luaL_error(L, "allocate EVP failed.");

  if (1 != EVP_DecryptInit_ex(ctx, aes_get_cipher(AES_GCM_MODE, bit), NULL, key, iv)){
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    lua_pushnil(L);
    lua_pushstring(L, "aes_decrypt_init failed.");
    return 2;
  }

  uint8_t *ciphertext = lua_newuserdata(L, text_sz);
  int len; int total;

  /* 添加`aad` */
  if(1 != EVP_DecryptUpdate(ctx, NULL, &len, aad, strlen((char*)aad))) {
    EVP_CIPHER_CTX_free(ctx);
    lua_pushnil(L);
    lua_pushstring(L, "aes_decrypt_update update aad failed.");
    return 2;
  }

  /* 添加加密文本 */
  if(!EVP_DecryptUpdate(ctx, ciphertext, &len, text, text_sz - 16)) {
    EVP_CIPHER_CTX_free(ctx);
    lua_pushnil(L);
    lua_pushstring(L, "aes_decrypt_update update aad failed.");
    return 2;
  }
  total = len;

  if(!EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_TAG, 16, text + text_sz - 16)) {
    EVP_CIPHER_CTX_free(ctx);
    lua_pushnil(L);
    lua_pushstring(L, "aes_decrypt_final set tag failed.");
    return 2;
  }

  if (EVP_DecryptFinal_ex(ctx, ciphertext + len, &len) <= 0) {
    EVP_CIPHER_CTX_free(ctx);
    lua_pushnil(L);
    lua_pushstring(L, "aes_decrypt_final flush data failed.");
    return 2;
  }

  lua_pushlstring(L, (const char*)ciphertext, total + len);
  EVP_CIPHER_CTX_free(ctx);
  return 1;
}