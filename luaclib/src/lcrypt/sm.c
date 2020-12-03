#include "lcrypt.h"

#if OPENSSL_VERSION_NUMBER < 0x10101000L || defined(OPENSSL_NO_SM2) || defined(OPENSSL_NO_SM3) || defined(OPENSSL_NO_SM4)

/* 不支持的情况下使用需要抛出异常. */
#define SM_THROW(L) luaL_error(L, "The current environment does not support the SM2/SM3/SM4 algorithm.")

int lsm3(lua_State *L) { return SM_THROW(L); }
int lhmac_sm3(lua_State *L) { return SM_THROW(L); }

int lsm4_cbc_encrypt(lua_State *L) { return SM_THROW(L); }
int lsm4_cbc_decrypt(lua_State *L) { return SM_THROW(L); }

int lsm4_ecb_encrypt(lua_State *L) { return SM_THROW(L); }
int lsm4_ecb_decrypt(lua_State *L) { return SM_THROW(L); }

int lsm4_ofb_encrypt(lua_State *L) { return SM_THROW(L); }
int lsm4_ofb_decrypt(lua_State *L) { return SM_THROW(L); }

int lsm4_ctr_encrypt(lua_State *L) { return SM_THROW(L); }
int lsm4_ctr_decrypt(lua_State *L) { return SM_THROW(L); }

int lsm2keygen(lua_State *L){ return SM_THROW(L); }

int lsm2sign(lua_State *L) { return SM_THROW(L); }
int lsm2verify(lua_State *L) { return SM_THROW(L); }

#else

#ifndef SM3_BLOCK_SIZE
	#define SM3_BLOCK_SIZE (32)
#endif

int lsm3(lua_State *L) {
	size_t textsize = 0;
	const uint8_t * text = (const uint8_t *)luaL_checklstring(L, 1, &textsize);
	EVP_MD_CTX *md_ctx = EVP_MD_CTX_new();
	EVP_DigestInit_ex(md_ctx, EVP_sm3(), NULL);
	EVP_DigestUpdate(md_ctx, text, textsize);
	uint32_t result_size = SM3_BLOCK_SIZE;
	uint8_t result[result_size];
	EVP_DigestFinal_ex(md_ctx, result, &result_size);
	EVP_MD_CTX_free(md_ctx);
	lua_pushlstring(L, (const char *)result, SM3_BLOCK_SIZE);
	return 1;
}

int lhmac_sm3(lua_State *L) {
  size_t key_sz = 0;
  size_t text_sz = 0;
  const char * key = luaL_checklstring(L, 1, &key_sz);
  if (!key || key_sz <= 0)
    return luaL_error(L, "Invalid key value.");

  const char * text = luaL_checklstring(L, 2, &text_sz);
  if (!text || text_sz <= 0)
    return luaL_error(L, "Invalid text value.");

  uint32_t result_len = SM3_BLOCK_SIZE;
  uint8_t result[result_len];
  memset(result, 0x0, result_len);
  HMAC(EVP_sm3(), (const unsigned char*)key, key_sz, (const unsigned char*)text, text_sz, result, &result_len);
  lua_pushlstring(L, (const char *)result, result_len);
  return 1;
}

/* 加密函数 */ 
static inline int sm4_encrypt(lua_State *L, const EVP_CIPHER *evp_md, const uint8_t *iv, const uint8_t *key, const uint8_t *text, size_t tsize) {
  EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
  if (!ctx)
    return luaL_error(L, "allocate EVP failed.");

  if (1 != EVP_EncryptInit_ex(ctx, evp_md, NULL, key, iv)){
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    return luaL_error(L, "SM4_ENCRYPT_INIT failed.");
  }

  EVP_CIPHER_CTX_set_padding(ctx, 1);
  // printf("key_len = %d\n", EVP_CIPHER_CTX_key_length(ctx));
  // printf("iv_len = %d\n", EVP_CIPHER_CTX_iv_length(ctx));
  // printf("block_size = %d\n", EVP_CIPHER_CTX_block_size(ctx));

  int out_size = tsize + EVP_MAX_BLOCK_LENGTH;
  uint8_t *out = lua_newuserdata(L, out_size);


  int update_len = out_size;
  if (1 != EVP_EncryptUpdate(ctx, out, &update_len, text, tsize)){
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    return luaL_error(L, "SM4_ENCRYPT_UPDATE failed.");
  }

  int final_len = out_size;
  if (1 != EVP_EncryptFinal(ctx, out + update_len, &final_len)){
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    return luaL_error(L, "SM4_ENCRYPT_FINAL failed.");
  }

  lua_pushlstring(L, (const char*)out, update_len + final_len);
  EVP_CIPHER_CTX_cleanup(ctx);
  EVP_CIPHER_CTX_free(ctx);
  return 1;
}

/* 解密函数 */ 
static inline int sm4_decrypt(lua_State *L, const EVP_CIPHER *evp_md, const uint8_t *iv, const uint8_t *key, const uint8_t *cipher, size_t csize) {
  EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
  if (!ctx)
    return luaL_error(L, "allocate EVP failed.");

  if (1 != EVP_DecryptInit_ex(ctx, evp_md, NULL, key, iv)){
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    return luaL_error(L, "SM4_DECRYPT_INIT failed.");
  }

  EVP_CIPHER_CTX_set_padding(ctx, 1);
  // printf("key_len = %d\n", EVP_CIPHER_CTX_key_length(ctx));
  // printf("iv_len = %d\n", EVP_CIPHER_CTX_iv_length(ctx));
  // printf("block_size = %d\n", EVP_CIPHER_CTX_block_size(ctx));

  int out_size = csize + EVP_MAX_BLOCK_LENGTH;
  uint8_t *out = lua_newuserdata(L, out_size);

  int update_len = out_size;
  if (1 != EVP_DecryptUpdate(ctx, out, &update_len, cipher, csize)){
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    return luaL_error(L, "SM4_DECRYPT_UPDATE failed.");
  }

  int final_len = out_size;
  if (1 != EVP_DecryptFinal_ex(ctx, out + update_len, &final_len)){
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    return luaL_error(L, "SM4_DECRYPT_FINAL failed.");
  }

  lua_pushlstring(L, (const char*)out, update_len + final_len);
  EVP_CIPHER_CTX_cleanup(ctx);
  EVP_CIPHER_CTX_free(ctx);
  return 1;
}

static inline const EVP_CIPHER* get_cipher(lua_State *L, int mode) {
  switch(mode){
    case 1:
      return EVP_sm4_cbc();
    case 2:
      return EVP_sm4_ecb();
    case 3:
      return EVP_sm4_ofb();
    case 4:
      return EVP_sm4_ctr();
  }
  return luaL_error(L, "Invalid SM4 CIPHER."), NULL;
}

static inline int lua_getarg(lua_State *L, const char **iv, const char **key, const char **text, size_t *tsize) {
  *key = luaL_checkstring(L, 1);
  if (!key)
    return luaL_error(L, "Invalid key");

  size_t size = 0;
  *text = luaL_checklstring(L, 2, &size);
  if (!text)
    return luaL_error(L, "Invalid text");
  *tsize = size;

  *iv = luaL_checkstring(L, 3);
  if (!iv)
    return luaL_error(L, "Invalid iv");
  return 1;
}


/* SM4加密函数的分组类型封装 */
int lsm4_cbc_encrypt(lua_State *L) {
  const char *iv; const char *key; const char *text; size_t tsize;
 //  lua_getarg(L, &iv, &key, &text, &tsize);
	// return 1;
  return lua_getarg(L, &iv, &key, &text, &tsize) && sm4_encrypt(L, get_cipher(L, 1), (const uint8_t *)iv, (const uint8_t *)key, (const uint8_t *)text, tsize);
}

int lsm4_ecb_encrypt(lua_State *L) {
  const char *iv; const char *key; const char *text; size_t tsize;
  // lua_getarg(L, &iv, &key, &text, &tsize);
  // return 1;
  return lua_getarg(L, &iv, &key, &text, &tsize) && sm4_encrypt(L, get_cipher(L, 2), (const uint8_t *)iv, (const uint8_t *)key, (const uint8_t *)text, tsize);
}

int lsm4_ofb_encrypt(lua_State *L) {
  const char *iv; const char *key; const char *text; size_t tsize;
 //  lua_getarg(L, &iv, &key, &text, &tsize);
	// return 1;
  return lua_getarg(L, &iv, &key, &text, &tsize) && sm4_encrypt(L, get_cipher(L, 3), (const uint8_t *)iv, (const uint8_t *)key, (const uint8_t *)text, tsize);
}

int lsm4_ctr_encrypt(lua_State *L) {
  const char *iv; const char *key; const char *text; size_t tsize;
  // lua_getarg(L, &iv, &key, &text, &tsize);
  // return 1;
  return lua_getarg(L, &iv, &key, &text, &tsize) && sm4_encrypt(L, get_cipher(L, 4), (const uint8_t *)iv, (const uint8_t *)key, (const uint8_t *)text, tsize);
}


/* SM4解密函数的分组类型封装 */
int lsm4_cbc_decrypt(lua_State *L) {
  const char *iv; const char *key; const char *cipher; size_t csize;
  // lua_getarg(L, &iv, &key, &cipher, &csize);
  // return 1;
  return lua_getarg(L, &iv, &key, &cipher, &csize) && sm4_decrypt(L, get_cipher(L, 1), (const uint8_t *)iv, (const uint8_t *)key, (const uint8_t *)cipher, csize);
}

int lsm4_ecb_decrypt(lua_State *L) {
  const char *iv; const char *key; const char *cipher; size_t csize;
  // lua_getarg(L, &iv, &key, &cipher, &csize);
  // return 1;
  return lua_getarg(L, &iv, &key, &cipher, &csize) && sm4_decrypt(L, get_cipher(L, 2), (const uint8_t *)iv, (const uint8_t *)key, (const uint8_t *)cipher, csize);
}

int lsm4_ofb_decrypt(lua_State *L) {
  const char *iv; const char *key; const char *cipher; size_t csize;
  // lua_getarg(L, &iv, &key, &cipher, &csize);
  // return 1;
  return lua_getarg(L, &iv, &key, &cipher, &csize) && sm4_decrypt(L, get_cipher(L, 3), (const uint8_t *)iv, (const uint8_t *)key, (const uint8_t *)cipher, csize);
}

int lsm4_ctr_decrypt(lua_State *L) {
  const char *iv; const char *key; const char *cipher; size_t csize;
  // lua_getarg(L, &iv, &key, &cipher, &csize);
  // return 1;
  return lua_getarg(L, &iv, &key, &cipher, &csize) && sm4_decrypt(L, get_cipher(L, 4), (const uint8_t *)iv, (const uint8_t *)key, (const uint8_t *)cipher, csize);
}

// 读取私钥
static inline EVP_PKEY* load_sm2prikey(lua_State *L) {
  const char* private_keyname = luaL_checkstring(L, 1);
  FILE *fp = fopen(private_keyname, "rb");
  if (!fp)
    return luaL_error(L, "Can't find `SM`2 privatekey in [%s] file.", private_keyname), NULL;

  EVP_PKEY *sm2key = PEM_read_PrivateKey(fp, NULL, NULL, NULL);
  if (!sm2key) {
    fclose(fp);
    return luaL_error(L, "Invalid `SM2` private key in [%s] file.", private_keyname), NULL;
  }
  fclose(fp);
  return sm2key;
}

// 读取公钥
static inline EVP_PKEY* load_sm2pubkey(lua_State *L) {
  const char* public_keyname = luaL_checkstring(L, 1);
  FILE *fp = fopen(public_keyname, "rb");
  if (!fp)
    return luaL_error(L, "Can't find `SM`2 publickey in [%s] file.", public_keyname), NULL;

  EVP_PKEY *sm2key = PEM_read_PUBKEY(fp, NULL, NULL, NULL);
  if (!sm2key) {
    fclose(fp);
    return luaL_error(L, "Invalid `SM2` publickey key in [%s] file.", public_keyname), NULL;
  }
  fclose(fp);
  return sm2key;
}

/* 生成 SM2 `私钥`与`公钥` */ 
static inline int sm2keygen(lua_State *L) {
  const char* private_keyname = luaL_checkstring(L, 1);
  const char* public_keyname = luaL_checkstring(L, 2);

	EVP_PKEY *sm2key = EVP_PKEY_new();
	EVP_PKEY_CTX *pctx = EVP_PKEY_CTX_new_id(EVP_PKEY_EC, NULL);
	EVP_PKEY_keygen_init(pctx);

	if (!EVP_PKEY_CTX_set_ec_paramgen_curve_nid(pctx, NID_sm2) || !EVP_PKEY_CTX_set_ec_param_enc(pctx, OPENSSL_EC_NAMED_CURVE) || EVP_PKEY_keygen(pctx, &sm2key) <= 0 ){
	  EVP_PKEY_free(sm2key);
	  EVP_PKEY_CTX_free(pctx);
		return luaL_error(L, "Generate SM2 key error.");
	}

  FILE *private_fp = fopen(private_keyname, "wb");
  FILE *public_fp = fopen(public_keyname, "wb");
  if (!private_fp || !public_fp) {
    if (private_fp)
      fclose(public_fp);
    if (public_fp)
      fclose(private_fp);
    EVP_PKEY_free(sm2key);
    EVP_PKEY_CTX_free(pctx);
    return luaL_error(L, "Write file failed after generate SM2 key.");
  }

  if (1 != PEM_write_PrivateKey(private_fp, sm2key, NULL, NULL, 0, NULL, NULL) || 1 != PEM_write_PUBKEY(public_fp, sm2key)) {
    fclose(private_fp);
    fclose(public_fp);
    EVP_PKEY_free(sm2key);
    EVP_PKEY_CTX_free(pctx);
    return luaL_error(L, "`SM2` privatekey/publickey write file failed.");
  }

  fclose(private_fp);
  fclose(public_fp);
  // 回收内存
  EVP_PKEY_free(sm2key);
  EVP_PKEY_CTX_free(pctx);
  return 0;
}

int lsm2keygen(lua_State *L){
	return sm2keygen(L);
}

int lsm2sign(lua_State *L){
  size_t tsize = 0;
  const char* text = luaL_checklstring(L, 2, &tsize);

  EVP_PKEY *sm2key = load_sm2prikey(L);
  EVP_PKEY_set_alias_type(sm2key, EVP_PKEY_SM2);

  size_t osize = EVP_PKEY_size(sm2key);
  const char *out = lua_newuserdata(L, osize);

  EVP_MD_CTX *md_ctx = EVP_MD_CTX_new();
  EVP_PKEY_CTX *pctx = EVP_PKEY_CTX_new(sm2key, NULL);
  EVP_MD_CTX_set_pkey_ctx(md_ctx, pctx);
  EVP_DigestSignInit(md_ctx, NULL, EVP_sm3(), NULL, sm2key);

  EVP_DigestSign(md_ctx, (uint8_t*)out, &osize, (uint8_t*)text, tsize);

  lua_pushlstring(L, out, osize);

  EVP_PKEY_free(sm2key);
  EVP_PKEY_CTX_free(pctx);
  EVP_MD_CTX_free(md_ctx);
  return 1;
}

int lsm2verify(lua_State *L){
  size_t tsize = 0;
  const char* text = luaL_checklstring(L, 2, &tsize);

  size_t csize = 0;
  const char* cipher = luaL_checklstring(L, 3, &csize);

  EVP_PKEY *sm2key = load_sm2pubkey(L);
  EVP_PKEY_set_alias_type(sm2key, EVP_PKEY_SM2);

  EVP_MD_CTX *md_ctx = EVP_MD_CTX_new();
  EVP_PKEY_CTX *pctx = EVP_PKEY_CTX_new(sm2key, NULL);
  EVP_MD_CTX_set_pkey_ctx(md_ctx, pctx);
  EVP_DigestVerifyInit(md_ctx, NULL, EVP_sm3(), NULL, sm2key);

  if (1 == EVP_DigestVerify(md_ctx, (uint8_t*)cipher, csize, (uint8_t*)text, tsize))
    lua_pushboolean(L, 1);
  else
    lua_pushboolean(L, 0);

  EVP_PKEY_free(sm2key);
  EVP_PKEY_CTX_free(pctx);
  EVP_MD_CTX_free(md_ctx);
  return 1;
}

#endif