#include "lcrypt.h"

/* -- Hashkey/Hmac_hash -- */

// Constants are the integer part of the sines of integers (in radians) * 2^32.
static const uint32_t k[64] = {
0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee ,
0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501 ,
0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be ,
0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821 ,
0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa ,
0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8 ,
0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed ,
0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a ,
0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c ,
0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70 ,
0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05 ,
0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665 ,
0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039 ,
0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1 ,
0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1 ,
0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391 };

// r specifies the per-round shift amounts
static const uint32_t r[] = {7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
            5,  9, 14, 20, 5,  9, 14, 20, 5,  9, 14, 20, 5,  9, 14, 20,
            4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
            6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21};

// leftrotate function definition
#define LEFTROTATE(x, c) (((x) << (c)) | ((x) >> (32 - (c))))

static inline void Hash(const char * str, int sz, uint8_t key[8]) {
  uint32_t djb_hash = 5381L;
  uint32_t js_hash = 1315423911L;

  int i;
  for (i=0;i<sz;i++) {
    uint8_t c = (uint8_t)str[i];
    djb_hash += (djb_hash << 5) + c;
    js_hash ^= ((js_hash << 5) + c + (js_hash >> 2));
  }

  key[0] = djb_hash & 0xff;
  key[1] = (djb_hash >> 8) & 0xff;
  key[2] = (djb_hash >> 16) & 0xff;
  key[3] = (djb_hash >> 24) & 0xff;

  key[4] = js_hash & 0xff;
  key[5] = (js_hash >> 8) & 0xff;
  key[6] = (js_hash >> 16) & 0xff;
  key[7] = (js_hash >> 24) & 0xff;
}

static inline void digest_md5(uint32_t w[16], uint32_t result[4]) {
  uint32_t a, b, c, d, f, g, temp;
  int i;

  a = 0x67452301u;
  b = 0xefcdab89u;
  c = 0x98badcfeu;
  d = 0x10325476u;

  for(i = 0; i<64; i++) {
    if (i < 16) {
      f = (b & c) | ((~b) & d);
      g = i;
    } else if (i < 32) {
      f = (d & b) | ((~d) & c);
      g = (5*i + 1) % 16;
    } else if (i < 48) {
      f = b ^ c ^ d;
      g = (3*i + 5) % 16;
    } else {
      f = c ^ (b | (~d));
      g = (7*i) % 16;
    }

    temp = d;
    d = c;
    c = b;
    b = b + LEFTROTATE((a + f + k[i] + w[g]), r[i]);
    a = temp;
  }

  result[0] = a;
  result[1] = b;
  result[2] = c;
  result[3] = d;
}

// hmac64 use md5 algorithm without padding, and the result is (c^d .. a^b)
static inline void hmac(uint32_t x[2], uint32_t y[2], uint32_t result[2]) {
  uint32_t w[16];
  uint32_t r[4];
  int i;
  for (i=0;i<16;i+=4) {
    w[i] = x[1];
    w[i+1] = x[0];
    w[i+2] = y[1];
    w[i+3] = y[0];
  }

  digest_md5(w,r);

  result[0] = r[2]^r[3];
  result[1] = r[0]^r[1];
}

static inline void hmac_md5(uint32_t x[2], uint32_t y[2], uint32_t result[2]) {
  uint32_t w[16];
  uint32_t r[4];
  int i;
  for (i=0;i<12;i+=4) {
    w[i] = x[0];
    w[i+1] = x[1];
    w[i+2] = y[0];
    w[i+3] = y[1];
  }

  w[12] = 0x80;
  w[13] = 0;
  w[14] = 384;
  w[15] = 0;

  digest_md5(w,r);

  result[0] = (r[0] + 0x67452301u) ^ (r[2] + 0x98badcfeu);
  result[1] = (r[1] + 0xefcdab89u) ^ (r[3] + 0x10325476u);
}

static inline void read64(lua_State *L, uint32_t xx[2], uint32_t yy[2]) {
  size_t sz = 0;
  const uint8_t *x = (const uint8_t *)luaL_checklstring(L, 1, &sz);
  if (sz != 8) {
    luaL_error(L, "Invalid uint64 x");
  }
  const uint8_t *y = (const uint8_t *)luaL_checklstring(L, 2, &sz);
  if (sz != 8) {
    luaL_error(L, "Invalid uint64 y");
  }
  xx[0] = x[0] | x[1]<<8 | x[2]<<16 | x[3]<<24;
  xx[1] = x[4] | x[5]<<8 | x[6]<<16 | x[7]<<24;
  yy[0] = y[0] | y[1]<<8 | y[2]<<16 | y[3]<<24;
  yy[1] = y[4] | y[5]<<8 | y[6]<<16 | y[7]<<24;
}

static inline int pushqword(lua_State *L, uint32_t result[2]) {
  uint8_t tmp[8];
  tmp[0] = result[0] & 0xff;
  tmp[1] = (result[0] >> 8 )& 0xff;
  tmp[2] = (result[0] >> 16 )& 0xff;
  tmp[3] = (result[0] >> 24 )& 0xff;
  tmp[4] = result[1] & 0xff;
  tmp[5] = (result[1] >> 8 )& 0xff;
  tmp[6] = (result[1] >> 16 )& 0xff;
  tmp[7] = (result[1] >> 24 )& 0xff;

  lua_pushlstring(L, (const char *)tmp, 8);
  return 1;
}

int lhmac64(lua_State *L) {
  uint32_t x[2], y[2];
  read64(L, x, y);
  uint32_t result[2];
  hmac(x,y,result);
  return pushqword(L, result);
}

/*
  h1 = crypt.hmac64_md5(a,b)
  m = md5.sum((a..b):rep(3))
  h2 = crypt.xor_str(m:sub(1,8), m:sub(9,16))
  assert(h1 == h2)
 */
int lhmac64_md5(lua_State *L) {
  uint32_t x[2], y[2];
  read64(L, x, y);
  uint32_t result[2];
  hmac_md5(x,y,result);
  return pushqword(L, result);
}

/*
  8bytes key
  string text
 */
int lhmac_hash(lua_State *L) {
  uint32_t key[2];
  size_t sz = 0;
  const uint8_t *x = (const uint8_t *)luaL_checklstring(L, 1, &sz);
  if (sz != 8) {
    luaL_error(L, "Invalid uint64 key");
  }
  key[0] = x[0] | x[1]<<8 | x[2]<<16 | x[3]<<24;
  key[1] = x[4] | x[5]<<8 | x[6]<<16 | x[7]<<24;
  const char * text = luaL_checklstring(L, 2, &sz);
  uint8_t h[8];
  Hash(text,(int)sz,h);
  uint32_t htext[2];
  htext[0] = h[0] | h[1]<<8 | h[2]<<16 | h[3]<<24;
  htext[1] = h[4] | h[5]<<8 | h[6]<<16 | h[7]<<24;
  uint32_t result[2];
  hmac(htext,key,result);
  return pushqword(L, result);
}

int lhashkey(lua_State *L) {
  size_t sz = 0;
  const char * key = luaL_checklstring(L, 1, &sz);
  uint8_t realkey[8];
  Hash(key,(int)sz,realkey);
  lua_pushlstring(L, (const char *)realkey, 8);
  return 1;
}

int lhmac_pbkdf2(lua_State *L) {

  EVP_MD *dig_md = (EVP_MD *)lua_touserdata(L, 1);
  if (!dig_md)
    return luaL_error(L, "Invalid pbkdf2 hash type.");

  int bsize = 0;
  if (dig_md == EVP_md5())
    bsize = MD5_DIGEST_LENGTH;
  else if (dig_md == EVP_sha1())
    bsize = SHA_DIGEST_LENGTH;
  else if (dig_md == EVP_sha224())
    bsize = SHA224_DIGEST_LENGTH;
  else if (dig_md == EVP_sha256())
    bsize = SHA256_DIGEST_LENGTH;
  else if (dig_md == EVP_sha384())
    bsize = SHA384_DIGEST_LENGTH;
  else if (dig_md == EVP_sha512())
    bsize = SHA512_DIGEST_LENGTH;
  else
    return luaL_error(L, "unsupported pbkdf2 hash type.");

  size_t psize;
  const char* password = (const char*)luaL_checklstring(L, 2, &psize);
  if (psize < 1)
    return luaL_error(L, "Invalid pbkdf2 password.");

  size_t sasize;
  const unsigned char* salt = (const unsigned char*)luaL_tolstring(L, 3, &sasize);
  if (sasize < 1)
    salt = NULL;

  lua_Integer iter = luaL_checkinteger(L, 4);
  unsigned char buffer[bsize];

  if (0 == PKCS5_PBKDF2_HMAC(password, psize, salt, sasize, iter > 0 ? iter : 1000, dig_md, bsize, buffer))
    return 0;

  lua_pushlstring(L, (const char*)buffer, bsize);
  return 1;
}