#include "lcrypt.h"

static inline int aes_is_gcm(const EVP_CIPHER * c)
{
  return (c == EVP_aes_128_gcm()) || (c == EVP_aes_192_gcm()) || (c == EVP_aes_256_gcm());
}

static inline int aes_is_ccm(const EVP_CIPHER * c)
{
  return (c == EVP_aes_128_ccm()) || (c == EVP_aes_192_ccm()) || (c == EVP_aes_256_ccm());
}

static inline const EVP_CIPHER * aes_get_cipher(int nid)
{
  return EVP_get_cipherbynid(nid);
}

// 加密函数
static int do_aes_encrypt(lua_State *L, const EVP_CIPHER *c, const uint8_t *key, size_t keylen, const uint8_t *iv, size_t ivlen, const uint8_t *text, size_t tsize, int padding, const uint8_t *aad, size_t aadlen, int taglen)
{
  EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
  EVP_CIPHER_CTX_set_padding(ctx, padding);

  /* 初始化失败 1 */
  if (1 != EVP_EncryptInit_ex(ctx, c, NULL, NULL, NULL)) {
    EVP_CIPHER_CTX_free(ctx);
    lua_pushnil(L);
    lua_pushstring(L, "[cipher error]: cipher enc_init failed.");
    return 2;
  }

  /* 设置 密钥 和 向量 的长度 */
  EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_SET_KEY_LENGTH, keylen, NULL);
  EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_SET_IVLEN, ivlen, NULL);

  /* 初始化失败 2 */
  if (1 != EVP_EncryptInit_ex(ctx, NULL, NULL, key, iv)) {
    EVP_CIPHER_CTX_free(ctx);
    lua_pushnil(L);
    lua_pushstring(L, "[cipher error]: cipher enc_init failed.");
    return 2;
  }

  if (aes_is_gcm(c) || aes_is_ccm(c))
  {
    int len = 0; /* CCM 模式需要 */
    if (aes_is_ccm(c))
    {
      if(1 != EVP_CipherUpdate(ctx, NULL, &len, NULL, tsize - taglen)){
        EVP_CIPHER_CTX_free(ctx);
        lua_pushnil(L);
        lua_pushfstring(L, "[cipher error]: clear aad `%s` failed.", (const char*)aad);
        return 2;
      }
    }
    len = 0;
    if(1 != EVP_CipherUpdate(ctx, NULL, &len, aad, aadlen)) {
      EVP_CIPHER_CTX_free(ctx);
      lua_pushnil(L);
      lua_pushfstring(L, "[cipher error]: update aad `%s` failed.", (const char*)aad);
      return 2;
    }
  }

  uint8_t *out; size_t olen = 0; int update_len;
  int osize = tsize + EVP_MAX_BLOCK_LENGTH + 16;
  if (osize <= 65535)
    out = alloca(osize);
  else
    out = lua_newuserdata(L, osize);

  if (1 != EVP_EncryptUpdate(ctx, out, &update_len, text, tsize))
  {
    EVP_CIPHER_CTX_free(ctx);
    lua_pushnil(L);
    lua_pushstring(L, "[cipher error]: enc update failed.");
    return 2;
  }
  olen += update_len;

  if (1 != EVP_EncryptFinal_ex(ctx, out + olen, &update_len))
  {
    EVP_CIPHER_CTX_free(ctx);
    lua_pushnil(L);
    lua_pushstring(L, "[cipher error]: enc final failed.");
    return 2;
  }
  olen += update_len;

  // printf("是否ccm or gcm ? %d\n", aes_is_gcm(c) || aes_is_ccm(c));
  if (aes_is_gcm(c) || aes_is_ccm(c))
  {
    // printf("加密有进入到这里吗?\n");
    if (1 != EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_GET_TAG, taglen, out + olen)) {
      EVP_CIPHER_CTX_free(ctx);
      lua_pushnil(L);
      lua_pushstring(L, "[cipher error]: EVP_CTRL_AEAD_GET_TAG failed.");
      return 2;
    }
    olen += taglen;
  }

  lua_pushlstring(L, (const char *)out, olen);
  EVP_CIPHER_CTX_free(ctx);
  return 1;
}

// 解密函数
static int do_aes_decrypt(lua_State *L, const EVP_CIPHER *c, const uint8_t *key, size_t keylen, const uint8_t *iv, size_t ivlen, const uint8_t *cipher, size_t csize, int padding, const uint8_t *aad, size_t aadlen, int taglen)
{
  EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
  EVP_CIPHER_CTX_set_padding(ctx, padding);

  /* 初始化失败 1 */
  if (1 != EVP_DecryptInit_ex(ctx, c, NULL, NULL, NULL)) {
    EVP_CIPHER_CTX_free(ctx);
    lua_pushnil(L);
    lua_pushstring(L, "[cipher error]: cipher dec_init failed.");
    return 2;
  }

  /* CCM 模式 没有这个会报错 */
  if (aes_is_ccm(c))
    EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_SET_TAG, taglen, (void *)((cipher + csize) - taglen));

  /* 设置 密钥 和 向量 的长度 */
  EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_SET_KEY_LENGTH, keylen, NULL);
  EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_SET_IVLEN, ivlen, NULL);

  /* 初始化失败 2 */
  if (1 != EVP_DecryptInit_ex(ctx, NULL, NULL, key, iv)) {
    EVP_CIPHER_CTX_free(ctx);
    lua_pushnil(L);
    lua_pushstring(L, "[cipher error]: cipher dec_init failed.");
    return 2;
  }

  if (aes_is_gcm(c) || aes_is_ccm(c))
  {
    int len = 0; /* CCM 模式需要 */
    if (aes_is_ccm(c))
    {
      if(1 != EVP_CipherUpdate(ctx, NULL, &len, NULL, csize - taglen)){
        EVP_CIPHER_CTX_free(ctx);
        lua_pushnil(L);
        lua_pushfstring(L, "[cipher error]: clear aad `%s` failed.", (const char*)aad);
        return 2;
      }
    }
    len = 0;
    if(1 != EVP_CipherUpdate(ctx, NULL, &len, aad, aadlen)) {
      EVP_CIPHER_CTX_free(ctx);
      lua_pushnil(L);
      lua_pushfstring(L, "[cipher error]: update aad `%s` failed.", (const char*)aad);
      return 2;
    }
  }

  uint8_t *out; size_t olen = 0; int update_len;
  int osize = csize + EVP_MAX_BLOCK_LENGTH + 16;
  if (osize <= 65535)
    out = alloca(osize);
  else
    out = lua_newuserdata(L, osize);

  if (1 != EVP_DecryptUpdate(ctx, out, &update_len, cipher, csize - taglen))
  {
    EVP_CIPHER_CTX_free(ctx);
    lua_pushnil(L);
    lua_pushstring(L, "[cipher error]: dec update failed.");
    return 2;
  }
  olen += update_len;

  /* 不同模式 */
  if (aes_is_gcm(c))
  {
    if (1 != EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_SET_TAG, taglen, (void *)((cipher + csize) - taglen))) {
      lua_pushnil(L);
      lua_pushstring(L, "[Cipher error]: EVP_CTRL_AEAD_SET_TAG failed.");
      return 2;
    }
  }

  /* 解密成功需要附加数据 */
  int ret = EVP_DecryptFinal_ex(ctx, out + olen, &update_len);
  if (1 != ret)
  {
    lua_pushnil(L);
    lua_pushstring(L, "[Cipher error]: dec final failed.");
    return 2;
  }
  olen += update_len;

  lua_pushlstring(L, (const char *)out, olen);
  EVP_CIPHER_CTX_free(ctx);
  return 1;
}

static inline int AES_ENCRYPT(lua_State *L) {

  size_t keylen;
  const uint8_t *key = (const uint8_t *)luaL_checklstring(L, 2, &keylen);

  size_t tlen;
  const uint8_t *text = (const uint8_t *)luaL_checklstring(L, 3, &tlen);

  size_t ivlen;
  const uint8_t *iv = (const uint8_t *)luaL_checklstring(L, 4, &ivlen);

  size_t aadlen;
  const uint8_t *aad = (const uint8_t *)lua_tolstring(L, 6, &aadlen);

  return do_aes_encrypt(L, (const EVP_CIPHER*)lua_touserdata(L, 1), key, keylen, iv, ivlen, text, tlen, luaL_optinteger(L, 5, EVP_PADDING_ZERO), aad, aadlen, luaL_optinteger(L, 7, 0));
}

static inline int AES_DECRYPT(lua_State *L) {

  size_t keylen;
  const uint8_t *key = (const uint8_t *)luaL_checklstring(L, 2, &keylen);

  size_t tlen;
  const uint8_t *text = (const uint8_t *)luaL_checklstring(L, 3, &tlen);

  size_t ivlen;
  const uint8_t *iv = (const uint8_t *)luaL_checklstring(L, 4, &ivlen);

  size_t aadlen;
  const uint8_t *aad = (const uint8_t *)lua_tolstring(L, 6, &aadlen);

  return do_aes_decrypt(L, (const EVP_CIPHER*)lua_touserdata(L, 1), key, keylen, iv, ivlen, text, tlen, luaL_optinteger(L, 5, EVP_PADDING_ZERO), aad, aadlen, luaL_optinteger(L, 7, 0));
}


int laes_enc(lua_State *L)
{
  return AES_ENCRYPT(L);
}

int laes_dec(lua_State *L)
{
  return AES_DECRYPT(L);
}