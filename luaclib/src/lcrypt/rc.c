#include "lcrypt.h"

#define RC4_set_key(key, len, data)             tc_rc4_set_key((key), (data), (len))
#define RC4(key, len, indata, outdata)          tc_rc4((key), (indata), (len), (outdata))
#define RC4_encrypt(key, len, indata, outdata)  RC4(key, len, indata, outdata)
#define RC4_decrypt(key, len, indata, outdata)  RC4(key, len, indata, outdata)

typedef struct tc_rc4_ctx {
  unsigned int x, y;
  unsigned int data[256];
} RC4_KEY;

int tc_rc4_set_key(RC4_KEY *key, const void *text, unsigned int tsize) {
  if (!key || !text || text == 0)
    return 0;
  memset(key, 0x0, sizeof(RC4_KEY));

  register uint32_t tmp;
  register uint32_t *d;
  register uint32_t id1, id2, i;

  id1 = id2 = 0;
  d = &(key->data[0]);
  for (i = 0; i < 256; i++)
    d[i] = i;

#define SK_LOOP(d,n)                                  \
  {                                                   \
    tmp = d[(n)];                                     \
    id2 = (((uint8_t*)text)[id1] + tmp + id2) & 0xff; \
    if (++id1 == tsize) id1=0;                        \
    d[(n)]=d[id2];                                    \
    d[id2]=tmp;                                       \
  }

  for (i = 0; i < 256; i += 4) {
    SK_LOOP(d, i + 0);
    SK_LOOP(d, i + 1);
    SK_LOOP(d, i + 2);
    SK_LOOP(d, i + 3);
  }
  return 1;
}

void* tc_rc4(RC4_KEY *key, const void *text, unsigned int tsize, unsigned char *md) {
  if (key == NULL || text == NULL || tsize == 0)
    return NULL;

  md = malloc(tsize);

  uint32_t *d; uint32_t i;
  uint32_t x, y, tx, ty;

  const unsigned char *indata  = text;
  unsigned char *outdata = md;

  x = key->x; y = key->y; d = key->data;

#define LOOP(in,out)                 \
    x=((x+1)&0xff);                  \
    tx=d[x];                         \
    y=(tx+y)&0xff;                   \
    d[x]=ty=d[y];                    \
    d[y]=tx;                         \
    (out) = d[(tx+ty)&0xff] ^ (in);

  i = tsize >> 3;
  if (i) {
      for (;;) {
        LOOP(indata[0], outdata[0]);
        LOOP(indata[1], outdata[1]);
        LOOP(indata[2], outdata[2]);
        LOOP(indata[3], outdata[3]);
        LOOP(indata[4], outdata[4]);
        LOOP(indata[5], outdata[5]);
        LOOP(indata[6], outdata[6]);
        LOOP(indata[7], outdata[7]);
        indata += 8; outdata += 8;
        if (--i == 0)
            break;
      }
  }
  i = tsize & 0x07;
  if (i) {
      for (;;) {
          LOOP(indata[0], outdata[0]);
          if (--i == 0)
              break;
          LOOP(indata[1], outdata[1]);
          if (--i == 0)
              break;
          LOOP(indata[2], outdata[2]);
          if (--i == 0)
              break;
          LOOP(indata[3], outdata[3]);
          if (--i == 0)
              break;
          LOOP(indata[4], outdata[4]);
          if (--i == 0)
              break;
          LOOP(indata[5], outdata[5]);
          if (--i == 0)
              break;
          LOOP(indata[6], outdata[6]);
          if (--i == 0)
              break;
      }
  }
  key->x = x; key->y = y;
  return md;
}

// RC4 对称加密/解密算法
int lrc4(lua_State *L) {
  size_t ksize = 0; size_t tsize = 0;

  const uint8_t* key = (const uint8_t*)luaL_checklstring(L, 1, &ksize);
  if (!key || ksize <= 0)
    return luaL_error(L, "Invalid rc4 key.");
  
  const uint8_t* text = (const uint8_t*)luaL_checklstring(L, 2, &tsize);
  if (!text || tsize <= 0)
    return luaL_error(L, "Invalid rc4 text.");

  char *buffer = lua_newuserdata(L, tsize);
  memset(buffer, 0x00, tsize);

  RC4_KEY rc4key;
  // 设置密钥
  RC4_set_key(&rc4key, ksize, key);
  // 加密/解密数据
  RC4(&rc4key, tsize, text, (uint8_t *)buffer);

  // 返回解密/解密的数据
  lua_pushlstring(L, buffer, tsize);

  return 1;
}