#include "lcrypt.h"

#define BASE64_CHUNK (16)

static inline int b64_calc_padding(const uint8_t *buffer, size_t len) {
  size_t n = 0;
  for (size_t i = 1; i <= 2; i++)
    if (buffer[len - i] == '=')
      n++;
  return n;
}

static inline void b64_trans_char(uint8_t *buf, size_t blen, char a1, char a2, char b1, char b2) {
  for (size_t i = 0; i < blen; i++)
  {
    if (buf[i] == a1)
      buf[i] = a2;
    else if (buf[i] == b1)
      buf[i] = b2;
  }
}

static inline void b64enc_trans_urlsafe(uint8_t *buf, size_t blen) {
  return b64_trans_char(buf, blen, '/', '_', '+', '-');
}

static inline const uint8_t* b64dec_trans_urlsafe(const uint8_t * __restrict buffer, uint8_t* __restrict rep, size_t len) {
  int urlsafe = 1; size_t pos = 0;
  for (size_t i = 0; i < len; i++)
  {
    if (buffer[i] == '_' || buffer[i] == '-')
    {
      pos = i;
      urlsafe = 0;
      break;
    }
  }
  if (urlsafe)
    return buffer;

  memcpy(rep, buffer, len);
  b64_trans_char(rep + pos, len - pos, '_', '/', '-', '+');
  return rep;
}

int lb64decode(lua_State *L) {
  size_t tsize = 0;
  const uint8_t* text = (const uint8_t *)luaL_checklstring(L, 1, &tsize);
  if (!text || tsize == 0)
    return 0;

  int urlsafe = lua_toboolean(L, 2);

  int padding = tsize % 4;

  EVP_ENCODE_CTX* ctx = EVP_ENCODE_CTX_new();
  EVP_DecodeInit(ctx);

  ssize_t nsize = BASE64_CHUNK;
  ssize_t bsize = BASE64_CHUNK;
  uint8_t buffer[bsize];
  uint8_t rep[bsize];

  luaL_Buffer B; luaL_buffinit(L, &B);
  while (tsize)
  {
    if (tsize < BASE64_CHUNK)
      bsize = tsize;

    int ret = EVP_DecodeUpdate(ctx, buffer, (int *)&nsize, urlsafe ? b64dec_trans_urlsafe(text, rep, bsize) : text, bsize);
    if(ret == -1)
      goto failed;

    luaL_addlstring(&B, (char *)buffer, nsize);

    if ((size_t)bsize == tsize)
    {
      if (padding)
      {
        EVP_DecodeUpdate(ctx, buffer, (int *)&nsize, (const uint8_t *)"===", 4 - padding);
        luaL_addlstring(&B, (char *)buffer, nsize);
      }
      break;
    }
    text += BASE64_CHUNK; tsize -= BASE64_CHUNK; nsize = bsize = BASE64_CHUNK;
  }

  bsize = BASE64_CHUNK;
  int ret = EVP_DecodeFinal(ctx, buffer, (int *)&bsize);
  if (ret == -1)
    goto failed;

  luaL_addlstring(&B, (char *)buffer, bsize);

  luaL_pushresult(&B);
  EVP_ENCODE_CTX_free(ctx);
  return 1;

  failed:
    EVP_ENCODE_CTX_free(ctx);
    return 0;
}

int lb64encode(lua_State *L) {
  size_t tsize = 0;
  const uint8_t* text = (const uint8_t *)luaL_checklstring(L, 1, &tsize);
  if (!text || tsize == 0)
    return 0;

  size_t blen = EVP_ENCODE_LENGTH(tsize);
  unsigned char* buf;
  if (blen < 65535)
    buf = alloca(blen);
  else
    buf = lua_newuserdata(L, blen);

  int len = EVP_EncodeBlock(buf, text, tsize);
  if (len < 1)
    return 0;

  /* 是否URL安全 */
  if (lua_toboolean(L, 2))
    b64enc_trans_urlsafe(buf, len);

  /* 是否去掉padding */
  if (lua_toboolean(L, 3))
    len -= b64_calc_padding(buf, len);

  lua_pushlstring(L, (char*)buf, len);
  return 1;
}