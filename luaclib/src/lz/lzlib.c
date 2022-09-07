/*
**  LICENSE: BSD
**  Author: CandyMi[https://github.com/candymi]
*/
#define LUA_LIB

#include <core.h>
#include <zlib.h>

/* 分配内存 */
void* stream_zalloc(void* opaque, unsigned items, unsigned nsize)
{
  (void)opaque;
  return xmalloc(((size_t)items) * ((size_t)nsize));
}

/* 释放内存 */
void stream_free(void* opaque, void* ptr) {
  (void)opaque;
  xfree(ptr);
}

void stream_init(z_stream *z) {
  memset(z, 0x0, sizeof(z_stream));
  z->zalloc = stream_zalloc;
  z->zfree  = stream_free;
}

/* 压缩 */
static inline int stream_deflate(lua_State* L, z_stream *z, int Z_MYMODE, const uint8_t* in, size_t in_size) {
  if (!z)
    return luaL_error(L, "[ZLIB ERROR]: `stream_deflate` got invalid `z_stream`.");

  if (Z_OK != deflateInit2(z, Z_DEFAULT_COMPRESSION, Z_DEFLATED, Z_MYMODE, MAX_MEM_LEVEL, Z_DEFAULT_STRATEGY))
    return luaL_error(L, "[ZLIB ERROR]: `stream_deflate` init failed.");

  /* 输入 */
  z->next_in = (uint8_t *)in; z->avail_in = in_size;

  /* 输出 */
  size_t out_size = deflateBound(z, in_size) + MAX_WBITS;
  uint8_t *out = lua_newuserdata(L, out_size);
  z->next_out = out; z->avail_out = out_size;

  /* 压缩数据 */
  deflate(z, Z_SYNC_FLUSH);
  deflateEnd(z);

  /* 结束 */
  lua_pushlstring(L, (const char*)out, z->total_out - 4);
  lua_pushinteger(L, in_size);
  return 2;
}

/* 解压 */
static inline int stream_inflate(lua_State* L, z_stream *z, int Z_MYWIND, const uint8_t* in, size_t in_size) {
  if (!z)
    return luaL_error(L, "[ZLIB ERROR]: `stream_inflate` got Invalid `z_stream`.");

  if (Z_OK != inflateInit2(z, Z_MYWIND))
    return luaL_error(L, "[ZLIB ERROR]: `stream_inflate` init failed.");

  /* 输入 */
  z->next_in = (uint8_t *)in; z->avail_in = in_size;

  /* 输出 */
  luaL_Buffer B; luaL_buffinit(L, &B);
  size_t bsize = 4096; uint8_t *buffer = alloca(bsize);

  size_t offset = 0; /* z->total_out - offset 真正的输出缓冲区的长度 */
  while (1)
  {
    z->next_out = buffer; z->avail_out = bsize;
    int ret = inflate(z, Z_SYNC_FLUSH);
    // printf("解压 : [ret] = %d, isize = [%ld], osize = [%ld]\n", ret, z->total_in, z->total_out);
    if (ret != Z_OK && ret != Z_STREAM_END) {
      inflateEnd(z);
      lua_pushboolean(L, 0);
      lua_pushfstring(L, "[ZLIB ERROR]: Invalid inflate buffer. %d", ret);
      return 2;
    }
    luaL_addlstring(&B, (char *)buffer, z->total_out - offset);
    // printf("buf[%s]\n", buffer);
    if (z->total_in == in_size)
      break;
    offset = z->total_out;
  }
  /* 结束 */
  inflateEnd(z);
  luaL_pushresult(&B);
  return 1;
}

/* RFC 1952 */
int lgzip_compress(lua_State* L) {
  z_stream z; stream_init(&z); size_t bsize;
  uint8_t *buffer = (uint8_t *)luaL_checklstring(L, 1, &bsize);
  return stream_deflate(L, &z, MAX_WBITS + 16, buffer, bsize);
}

int lgzip_uncompress(lua_State* L) {
  z_stream z; stream_init(&z); size_t bsize;
  uint8_t *buffer = (uint8_t *)luaL_checklstring(L, 1, &bsize);
  return stream_inflate(L, &z, MAX_WBITS + 16, buffer, bsize);
}

/* RFC 1951 */
int ldeflate_compress(lua_State* L) {
  z_stream z; stream_init(&z); size_t bsize;
  uint8_t *buffer = (uint8_t *)luaL_checklstring(L, 1, &bsize);
  return stream_deflate(L, &z, -MAX_WBITS, buffer, bsize);
}

int ldeflate_uncompress(lua_State* L) {
  z_stream z; stream_init(&z); size_t bsize;
  uint8_t *buffer = (uint8_t *)luaL_checklstring(L, 1, &bsize);
  return stream_inflate(L, &z, -MAX_WBITS, buffer, bsize);
}

/* RFC 1950 */
int lzlib_compress(lua_State* L) {
  z_stream z; stream_init(&z); size_t bsize;
  uint8_t *buffer = (uint8_t *)luaL_checklstring(L, 1, &bsize);
  return stream_deflate(L, &z, MAX_WBITS, buffer, bsize);
}

int lzlib_uncompress(lua_State* L) {
  z_stream z; stream_init(&z); size_t bsize;
  uint8_t *buffer = (uint8_t *)luaL_checklstring(L, 1, &bsize);
  return stream_inflate(L, &z, MAX_WBITS, buffer, bsize);
}

/* RFC 7692 */
int lws_compress(lua_State* L) {
  // z_stream z; stream_init(&z); size_t bsize;
  // uint8_t *buffer = (uint8_t *)luaL_checklstring(L, 1, &bsize);
  // return stream_deflate(L, &z, -MAX_WBITS, buffer, bsize);
  return ldeflate_compress(L);
}

int lws_uncompress(lua_State* L) {
  // z_stream z; stream_init(&z); size_t bsize;
  // uint8_t *buffer = (uint8_t *)luaL_checklstring(L, 1, &bsize);
  // return stream_inflate(L, &z, -MAX_WBITS, buffer, bsize);
  return ldeflate_uncompress(L);
}

LUAMOD_API int luaopen_lz(lua_State *L) {
  luaL_checkversion(L);
  luaL_Reg zlib_libs[] = {
    /* LZ77压缩/解压方法 */
    {"compress",      ldeflate_compress},
    {"uncompress",    ldeflate_uncompress},
    /* 原生压缩方法 */
    {"compress2",     lzlib_compress},
    {"uncompress2",   lzlib_uncompress},
    /* gzip压缩/解压方法 */
    {"gzcompress",    lgzip_compress},
    {"gzuncompress",  lgzip_uncompress},
    /* Websocket压缩/解压方法 */
    {"wscompress",    lws_compress},
    {"wsuncompress",  lws_uncompress},
    {NULL, NULL}
  };
  luaL_newlib(L, zlib_libs);
  return 1;
}
