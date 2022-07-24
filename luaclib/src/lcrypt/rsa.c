#include "lcrypt.h"

static inline RSA* new_public_key(lua_State *L) {
  size_t p_size = 0;
  const uint8_t* p_path = (const uint8_t*)luaL_checklstring(L, 2, &p_size);
  if (!p_path || p_size <= 0)
    return NULL;

  RSA* key;
  BIO* IO = BIO_new(BIO_s_mem()); BIO_write(IO, (const char *)p_path, p_size);
  key = PEM_read_bio_RSAPublicKey(IO, NULL, NULL, NULL);
  if (!key) {
    BIO_write(IO, (const char *)p_path, p_size); /* 重新写入 */
    key = PEM_read_bio_RSA_PUBKEY(IO, NULL, NULL, NULL);
  }
  BIO_free(IO);
  if (key){
    // RSA_print_fp(stdout, key, 0);
    return key;
  }
  FILE* f = fopen((const char *)p_path, "rb");
  if (!f)
    return NULL;

  key = PEM_read_RSAPublicKey(f, NULL, NULL, NULL);
  if (!key){
    fseek(f, SEEK_SET, 0); /* 需要将指针重置为开头 */
    key = PEM_read_RSA_PUBKEY(f, NULL, NULL, NULL);
  }
  // RSA_print_fp(stdout, key, 0);
  fclose(f);
  return key;
}

static inline RSA* new_private_key(lua_State *L) {
  size_t p_size = 0;
  const uint8_t* p_path = (const uint8_t*)luaL_checklstring(L, 2, &p_size);
  if (!p_path || p_size <= 0)
    return NULL;

  RSA* key;
  BIO* IO = BIO_new(BIO_s_mem()); BIO_write(IO, (const char *)p_path, p_size);
  key = PEM_read_bio_RSAPrivateKey(IO, NULL, NULL, NULL);
  BIO_free(IO);
  if (key){
    // RSA_print_fp(stdout, key, 0);
    return key;
  }
  FILE* f = fopen((const char *)p_path, "rb");
  if (!f)
    return NULL;

  key = PEM_read_RSAPrivateKey(f, NULL, NULL, NULL);
  // RSA_print_fp(stdout, key, 0);
  fclose(f);
  return key;
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

  ssize_t len = RSA_private_decrypt(text_size, text, result, key, get_mode(L));
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

  ssize_t len = RSA_public_decrypt(text_size, text, result, key, get_mode(L));
  if (0 > len) {
    RSA_free(key);
    luaL_pushresultsize(&b, 0);
    return luaL_error(L, "public_key_decode text falied.");
  }

  luaL_pushresultsize(&b, len);
  RSA_free(key);
  return 1;
}

// 获取签名算法类型
static inline int get_sign_algorithm(lua_State *L, int pos) {
  switch(lua_tointeger(L, pos)) {
    case NID_sha1:
      return NID_sha1;
    case NID_sha256:
      return NID_sha256;
    case NID_sha512:
      return NID_sha512;
  }
  return NID_md5;
}

// 计算输出长度
static inline int calc_result_len(lua_State *L, int pos) {
  switch(lua_tointeger(L, pos)) {
    case NID_sha1:
      return SHA_DIGEST_LENGTH;
    case NID_sha256:
      return SHA256_DIGEST_LENGTH;
    case NID_sha512:
      return SHA512_DIGEST_LENGTH;
  }
  return MD5_DIGEST_LENGTH;
}

// 计算hash
static inline void rsa_hash(lua_State *L, int pos, const uint8_t* text, size_t tsize, uint8_t* data) {
  switch(lua_tointeger(L, pos)) {
    case NID_sha1:
      SHA1(text, tsize, data);
      return ;
    case NID_sha256:
      SHA256(text, tsize, data);
      return ;
    case NID_sha512:
      SHA512(text, tsize, data);
      return ;
  }
  MD5(text, tsize, data);
  return ;
}

// RSA签名算法
int lrsa_sign(lua_State *L) {
  size_t tsize = 0;
  const uint8_t* text = get_text(L, &tsize);
  if (!text || tsize < 1)
    return luaL_error(L, "Invalid text");

  RSA* rsa = new_private_key(L);
  if (!rsa)
    return luaL_error(L, "Can't find valide private rsa.");

  int sign_len = calc_result_len(L, 3);
  unsigned char sign[sign_len];
  rsa_hash(L, 3, text, tsize, sign);

  luaL_Buffer b;
  unsigned char* result = (unsigned char*)luaL_buffinitsize(L, &b, RSA_size(rsa));
  uint32_t result_size = RSA_size(rsa);

  if (1 != RSA_sign(get_sign_algorithm(L, 3), sign, sign_len, result, &result_size, rsa))
    lua_pushboolean(L, 0);
  else
    luaL_pushresultsize(&b, result_size);

  RSA_free(rsa);
  return 1;
}

// RSA验签算法
int lrsa_verify(lua_State *L) {
  size_t tsize = 0;
  const uint8_t* text = get_text(L, &tsize);
  if (!text || tsize < 1)
    return luaL_error(L, "Invalid text");

  RSA* rsa = new_public_key(L);
  if (!rsa)
    return luaL_error(L, "Can't find valide public rsa.");

  size_t ssize = 0;
  const uint8_t *sign = (const uint8_t*)luaL_checklstring(L, 3, &ssize);
  if (!sign || ssize < 1)
    return luaL_error(L, "Invalid sign");

  int data_len = calc_result_len(L, 4);
  unsigned char data[data_len];
  rsa_hash(L, 4, text, tsize, data);

  if (1 != RSA_verify(get_sign_algorithm(L, 4), data, data_len, sign, ssize, rsa))
    lua_pushboolean(L, 0);
  else
    lua_pushboolean(L, 1);

  RSA_free(rsa);
  return 1;
}
