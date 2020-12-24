#define LUA_LIB

#include <core.h>
#include <zlib.h>

#define MAX_COMPRESS_BUF_SIZE_TIMES (1 << 10)

static inline void stream_init(z_stream *z) {
  memset(z, 0x0, sizeof(*z));
  z->zalloc = Z_NULL;
  z->zfree = Z_NULL;
  z->opaque = Z_NULL;
}

static int lcompress(lua_State *L) {
  size_t in_size = 0;
  const uint8_t* in = (const uint8_t*)luaL_checklstring(L, 1, &in_size);
  if (in_size <= 0)
    return 0;

  size_t out_size = compressBound(in_size);
  uint8_t *out = lua_newuserdata(L, out_size);
  memset(out, 0x0, out_size);

  if (compress(out, &out_size, in, in_size) != Z_OK)
    return 0;

  lua_pushlstring(L, (const char*)out, out_size);
  lua_pushinteger(L, in_size);
  return 2;
}

static int luncompress(lua_State *L) {
  size_t in_size = 0;
  const uint8_t* in = (const uint8_t*)luaL_checklstring(L, 1, &in_size);
  if (in_size <= 0)
    return 0;

  size_t out_size = in_size;

  /* 若能传递压缩前的大小, 优先使用此数值 */
  int is_sum = 0;
  lua_Integer before_size = lua_tointegerx(L, 2, &is_sum);
  if (is_sum && before_size > 0 )
    out_size = before_size;

  size_t offset = 1;
  size_t top = lua_gettop(L);

  do {
    uint8_t *out = lua_newuserdata(L, out_size);
    memset(out, 0x0, out_size);

    int ret = uncompress(out, &out_size, in, in_size);
    if (ret == Z_OK || ret == Z_BUF_ERROR) {
      if (ret == Z_OK){
        lua_pushlstring(L, (const char *)out, out_size);
        return 1;        
      }
      lua_settop(L, top);
      offset ++;
      out_size = in_size << offset;
      continue;
    }
  } while(0);
  return 0;
}

static int lgzip_compress(lua_State *L) {
  size_t in_size = 0;
  const char* in = luaL_checklstring(L, 1, &in_size);
  if (in_size <= 0)
    return 0;

  z_stream z;
  stream_init(&z);

  int ok = deflateInit2(&z, Z_DEFAULT_COMPRESSION, Z_DEFLATED, MAX_WBITS + 16, MAX_MEM_LEVEL, Z_DEFAULT_STRATEGY);
  if (Z_OK != ok)
    return 0;

  z.next_in = (uint8_t *)in;
  z.avail_in = in_size;

  luaL_Buffer B;
  z.avail_out = deflateBound(&z, in_size);
  z.next_out = (uint8_t *)luaL_buffinitsize(L, &B, z.avail_out);
  memset(z.next_out, 0x0, z.avail_out);

  int ret = deflate(&z, Z_FINISH);
  if (ret != Z_STREAM_END) {
    luaL_pushresultsize(&B, 0);
    deflateEnd(&z);
    return 0;
  }
  if (deflateEnd(&z) != Z_OK){
    luaL_pushresultsize(&B, 0);
    return 0;
  }
  luaL_pushresultsize(&B, z.total_out);
  return 1;
}

static int lgzip_uncompress(lua_State *L) {
  size_t in_size = 0;
  const char* in = luaL_checklstring(L, 1, &in_size);
  if (in_size <= 0)
    return 0;

  z_stream z;
  stream_init(&z);

  int ok = inflateInit2(&z, MAX_WBITS + 16);
  if (Z_OK != ok)
    return 0;

  size_t out_size = in_size << 1;
  int top = lua_gettop(L);

  for(;;) {
    luaL_Buffer B;
    z.next_in = (uint8_t *)in;
    z.avail_in = in_size;
    z.avail_out = out_size;
    z.next_out = (uint8_t *)luaL_buffinitsize(L, &B, out_size);
    memset(z.next_out, 0x0, z.avail_out);

    int ret = inflate(&z, Z_FINISH);
    if (ret == Z_STREAM_END) {
      int ok = inflateEnd(&z);
      if (ok != Z_OK)
        return 0;
      luaL_pushresultsize(&B, z.total_out);
      break;
    }
    if (ret != Z_BUF_ERROR) {
      luaL_pushresultsize(&B, 0);
      inflateEnd(&z);
      return 0;
    }
    /* 防止内存溢出 */
    if (out_size > in_size * MAX_COMPRESS_BUF_SIZE_TIMES){
      luaL_pushresultsize(&B, 0);
      inflateEnd(&z);
      return 0;
    }
    inflateReset(&z);
    out_size <<= 1;
    luaL_pushresultsize(&B, 0);
    lua_settop(L, top);
  }
  return 1;
}

static int lcompress2(lua_State *L) {
  size_t in_size = 0;
  const char* in = luaL_checklstring(L, 1, &in_size);
  if (in_size <= 0)
    return 0;

  z_stream z;
  stream_init(&z);

  int ok = deflateInit2(&z, Z_DEFAULT_COMPRESSION, Z_DEFLATED, MAX_WBITS * -1, MAX_MEM_LEVEL, Z_DEFAULT_STRATEGY);
  if (Z_OK != ok)
    return 0;

  z.next_in = (uint8_t *)in;
  z.avail_in = in_size;

  luaL_Buffer B;
  z.avail_out = deflateBound(&z, in_size);
  z.next_out = (uint8_t *)luaL_buffinitsize(L, &B, z.avail_out);
  memset(z.next_out, 0x0, z.avail_out);

  int ret = deflate(&z, Z_FINISH);
  if (ret != Z_STREAM_END) {
    luaL_pushresultsize(&B, 0);
    deflateEnd(&z);
    return 0;
  }
  if (deflateEnd(&z) != Z_OK){
    luaL_pushresultsize(&B, 0);
    return 0;
  }
  luaL_pushresultsize(&B, z.total_out);
  lua_pushinteger(L, in_size);
  return 2;
}

static int luncompress2(lua_State *L) {
  size_t in_size = 0;
  const char* in = luaL_checklstring(L, 1, &in_size);
  if (in_size <= 0)
    return 0;

  z_stream z;
  stream_init(&z);

  int ok = inflateInit2(&z, MAX_WBITS * -1);
  if (Z_OK != ok)
    return 0;

  size_t out_size = in_size * 4;
  int top = lua_gettop(L);

  for(;;) {
    luaL_Buffer B;
    z.next_in = (uint8_t *)in;
    z.avail_in = in_size;
    z.avail_out = out_size;
    z.next_out = (uint8_t *)luaL_buffinitsize(L, &B, out_size);
    memset(z.next_out, 0x0, z.avail_out);

    int ret = inflate(&z, Z_FINISH);
    if (ret == Z_STREAM_END) {
      int ok = inflateEnd(&z);
      if (ok != Z_OK)
        return 0;
      luaL_pushresultsize(&B, z.total_out);
      break;
    }
    if (ret != Z_BUF_ERROR) {
      luaL_pushresultsize(&B, 0);
      inflateEnd(&z);
      return 0;
    }
    /* 防止内存溢出 */
    if (out_size > in_size * MAX_COMPRESS_BUF_SIZE_TIMES){
      luaL_pushresultsize(&B, 0);
      inflateEnd(&z);
      return 0;
    }
    inflateReset(&z);
    out_size *= 2;
    luaL_pushresultsize(&B, 0);
    lua_settop(L, top);
  }
  return 1;
}

LUAMOD_API int luaopen_lz(lua_State *L){
  luaL_checkversion(L);
  luaL_Reg zlib_libs[] = {
    /* LZ77压缩/解压方法 */
    {"compress", lcompress},
    {"uncompress", luncompress},
    /* 原生压缩方法 */
    {"compress2", lcompress2},
    {"uncompress2", luncompress2},
    /* gzip压缩/解压方法 */
    {"gzcompress", lgzip_compress},
    {"gzuncompress", lgzip_uncompress},
    {NULL, NULL}
  };
  luaL_newlib(L, zlib_libs);
  return 1;
}