#include "lcrypt.h"

// powmodp64 for DH-key exchange

// The biggest 64bit prime
#define P 0xffffffffffffffc5ull

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

static inline uint64_t mul_mod_p(uint64_t a, uint64_t b) {
  uint64_t m = 0;
  while(b) {
    if(b&1) {
      uint64_t t = P-a;
      if ( m >= t) {
        m -= t;
      } else {
        m += a;
      }
    }
    if (a >= P - a) {
      a = a * 2 - P;
    } else {
      a = a * 2;
    }
    b>>=1;
  }
  return m;
}

static inline uint64_t pow_mod_p(uint64_t a, uint64_t b) {
  if (b==1) {
    return a;
  }
  uint64_t t = pow_mod_p(a, b>>1);
  t = mul_mod_p(t,t);
  if (b % 2) {
    t = mul_mod_p(t, a);
  }
  return t;
}

// calc a^b % p
static inline uint64_t powmodp(uint64_t a, uint64_t b) {
  if (a > P)
    a%=P;
  return pow_mod_p(a,b);
}

static inline void push64(lua_State *L, uint64_t r) {
  uint8_t tmp[8];
  tmp[0] = r & 0xff;
  tmp[1] = (r >> 8 )& 0xff;
  tmp[2] = (r >> 16 )& 0xff;
  tmp[3] = (r >> 24 )& 0xff;
  tmp[4] = (r >> 32 )& 0xff;
  tmp[5] = (r >> 40 )& 0xff;
  tmp[6] = (r >> 48 )& 0xff;
  tmp[7] = (r >> 56 )& 0xff;

  lua_pushlstring(L, (const char *)tmp, 8);
}

int ldhsecret(lua_State *L) {
  uint32_t x[2], y[2];
  read64(L, x, y);
  uint64_t xx = (uint64_t)x[0] | (uint64_t)x[1]<<32;
  uint64_t yy = (uint64_t)y[0] | (uint64_t)y[1]<<32;
  if (xx == 0 || yy == 0)
    return luaL_error(L, "Can't be 0");
  uint64_t r = powmodp(xx, yy);

  push64(L, r);

  return 1;
}

#define G 5

int ldhexchange(lua_State *L) {
  size_t sz = 0;
  const uint8_t *x = (const uint8_t *)luaL_checklstring(L, 1, &sz);
  if (sz != 8) {
    luaL_error(L, "Invalid dh uint64 key");
  }
  uint32_t xx[2];
  xx[0] = x[0] | x[1]<<8 | x[2]<<16 | x[3]<<24;
  xx[1] = x[4] | x[5]<<8 | x[6]<<16 | x[7]<<24;

  uint64_t x64 = (uint64_t)xx[0] | (uint64_t)xx[1]<<32;
  if (x64 == 0)
    return luaL_error(L, "Can't be 0");

  uint64_t r = powmodp(G, x64);
  push64(L, r);
  return 1;
}