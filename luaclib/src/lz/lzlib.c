#define LUA_LIB

#include <core.h>
#include <zlib.h>

#ifndef MAX_WBITS
#  define MAX_WBITS   15 /* 32K LZ77 window */
#endif

// 压缩模式
enum zmode {
  Z_COMPRESS1_MODE   =  0,
  Z_COMPRESS2_MODE   =  1,
  Z_GZCOMPRESS_MODE  =  2,
};

// 压缩窗口大小
enum zwsize {
  Z_COMPRESS1_WSIZE   =  +MAX_WBITS,
  Z_COMPRESS2_WSIZE   =  -MAX_WBITS,
  Z_GZCOMPRESS_WSIZE  =  MAX_WBITS + 16,
};

static int zwindow[] = { Z_COMPRESS1_WSIZE, Z_COMPRESS2_WSIZE, Z_GZCOMPRESS_WSIZE };

// 初始化
static inline void stream_init(z_stream *z) {
  memset(z, 0x0, sizeof(z_stream));
  z->zalloc = Z_NULL;
  z->zfree = Z_NULL;
  z->opaque = Z_NULL;
}

// 压缩
static inline int stream_deflate(lua_State* L, int mode, const uint8_t* in, size_t in_size) {

  z_stream z;
  stream_init(&z);

  size_t out_size;
  uint8_t *out;

  if (Z_OK != deflateInit2(&z, Z_DEFAULT_COMPRESSION, Z_DEFLATED, zwindow[mode], MAX_MEM_LEVEL, Z_DEFAULT_STRATEGY))
    return luaL_error(L, "[ZLIB ERROR]: deflateInit init failed.");

  out_size = deflateBound(&z, in_size);
  out = lua_newuserdata(L, out_size);

  // 输入
  z.next_in = (uint8_t *)in;
  z.avail_in = in_size;

  z.next_out  = out;
  z.avail_out = out_size;

  int ret = deflate(&z, Z_FINISH);
  // 压缩
  if (ret != Z_STREAM_END) {
    deflateEnd(&z);
    return luaL_error(L, "[ZLIB ERROR]: deflate error(%d).", ret);
  }
  // 清理
  if (deflateEnd(&z) != Z_OK){
    return luaL_error(L, "[ZLIB ERROR]: deflateEnd error(%d).", ret);
  }
  // 结束
  lua_pushlstring(L, (const char*)out, z.total_out);
  lua_pushinteger(L, in_size);
  return 2;
}

// 解缩
static inline int stream_inflate(lua_State* L, int windsize, const uint8_t* in, size_t in_size) {
  z_stream z;
  stream_init(&z);

  z.next_in = (uint8_t *)in;
  z.avail_in = in_size;

  if (Z_OK != inflateInit2(&z, windsize))
    return luaL_error(L, "[ZLIB ERROR]: inflateInit init failed.");

  luaL_Buffer B;
  luaL_buffinit(L, &B);

  int bszie = 65535;
  uint8_t buffer[bszie];

  uint64_t offset = 0;

  for (;;) {  
    z.next_out = buffer;
    z.avail_out = bszie;
    // 始终用最小的内存来解压数据.
    int ret = inflate(&z, Z_NO_FLUSH);
    // 如果已经到数据流的尾部.
    if (ret == Z_STREAM_END){
      luaL_addlstring(&B, (const char*)buffer, z.total_out - offset);
      offset = z.total_out;
      break;
    }
    // 如果数据出现其他异常情况
    if (ret != Z_OK){
      inflateEnd(&z);
      lua_pushboolean(L, 0);
      lua_pushfstring(L, "[ZLIB ERROR]: Invalid inflate buffer. %d", ret);
      return 2;
    }
    // printf("inline : [ret] = %d, isize = [%ld], osize = [%ld]\n", ret, z.total_in, z.total_out);
    // 每次迭代都需要把缓冲区的数据添加到内部.
    luaL_addlstring(&B, (const char*)buffer, z.total_out - offset);
    offset = z.total_out;
  }
  
  int ret = inflateEnd(&z);
  if (ret != Z_OK){
    lua_pushboolean(L, 0);
    lua_pushfstring(L, "[ZLIB ERROR]: Invalid inflateEnd buffer. %d", ret);
    return 2;
  }
  // printf("over: [ret] = %d, isize = [%ld], osize = [%ld]\n", ret, z.total_in, z.total_out);
  luaL_pushresult(&B);
  return 1;
}

static int lcompress(lua_State *L) {
  size_t in_size = 0;
  const uint8_t* in = (const uint8_t*)luaL_checklstring(L, 1, &in_size);
  if (in_size <= 0)
    return luaL_error(L, "[ZLIB ERROR]: Invalid in buffer.");

  return stream_deflate(L, Z_COMPRESS1_MODE, (const uint8_t*)in, in_size);
}

static int luncompress(lua_State *L) {
  size_t in_size = 0;
  const uint8_t* in = (const uint8_t*)luaL_checklstring(L, 1, &in_size);
  if (in_size <= 0)
    return luaL_error(L, "[ZLIB ERROR]: Invalid in buffer.");

  return stream_inflate(L, Z_COMPRESS1_WSIZE, (const uint8_t*)in, in_size);
}

static int lcompress2(lua_State *L) {
  size_t in_size = 0;
  const uint8_t* in = (const uint8_t*)luaL_checklstring(L, 1, &in_size);
  if (in_size <= 0)
    return luaL_error(L, "[ZLIB ERROR]: Invalid in buffer.");

  return stream_deflate(L, Z_COMPRESS2_MODE, (const uint8_t*)in, in_size);
}

static int luncompress2(lua_State *L) {
  size_t in_size = 0;
  const uint8_t* in = (const uint8_t*)luaL_checklstring(L, 1, &in_size);
  if (in_size <= 0)
    return luaL_error(L, "[ZLIB ERROR]: Invalid in buffer.");

  return stream_inflate(L, Z_COMPRESS2_WSIZE, (const uint8_t*)in, in_size);
}

static int lgzip_compress(lua_State *L) {
  size_t in_size = 0;
  const uint8_t* in = (const uint8_t*)luaL_checklstring(L, 1, &in_size);
  if (in_size <= 0)
    return luaL_error(L, "[ZLIB ERROR]: Invalid in buffer.");

  return stream_deflate(L, Z_GZCOMPRESS_MODE, (const uint8_t*)in, in_size);
}

static int lgzip_uncompress(lua_State *L) {
  size_t in_size = 0;
  const uint8_t* in = (const uint8_t*)luaL_checklstring(L, 1, &in_size);
  if (in_size <= 0)
    return luaL_error(L, "[ZLIB ERROR]: Invalid in buffer.");

  return stream_inflate(L, Z_GZCOMPRESS_WSIZE, (const uint8_t*)in, in_size);
}

static int lws_compress(lua_State *L) {
  size_t in_size = 0;
  const uint8_t* in = (const uint8_t*)luaL_checklstring(L, 1, &in_size);
  if (in_size <= 0)
    return luaL_error(L, "[ZLIB ERROR]: Invalid in buffer.");

  z_stream z;
  stream_init(&z);

  if (Z_OK != deflateInit2(&z, Z_DEFAULT_COMPRESSION, Z_DEFLATED, Z_COMPRESS2_WSIZE, MAX_MEM_LEVEL, Z_DEFAULT_STRATEGY))
    return luaL_error(L, "[ZLIB ERROR]: deflateInit init failed.");

  size_t out_size = deflateBound(&z, in_size);
  uint8_t *out = lua_newuserdata(L, out_size);

  // 输入
  z.next_in = (uint8_t *)in;
  z.avail_in = in_size;

  z.next_out  = out;
  z.avail_out = out_size;

  int ret = deflate(&z, Z_FINISH);
  // 压缩
  if (ret != Z_STREAM_END) {
    deflateEnd(&z);
    return luaL_error(L, "[ZLIB ERROR]: deflate error(%d).", ret);
  }
  // 清理
  if (deflateEnd(&z) != Z_OK){
    return luaL_error(L, "[ZLIB ERROR]: deflateEnd error(%d).", ret);
  }

  out[0] = out[0] - 1;

  // 结束
  lua_pushlstring(L, (const char*)out, z.total_out);
  lua_pushinteger(L, in_size);
  return 2;
}

static int lws_uncompress(lua_State *L) {
  size_t in_size = 0;
  const uint8_t* in = (const uint8_t*)luaL_checklstring(L, 1, &in_size);
  if (in_size <= 0)
    return luaL_error(L, "[ZLIB ERROR]: Invalid in buffer.");

  char *buf = (char *)in;
  buf[0] = buf[0] + 1;
  int ret = stream_inflate(L, Z_COMPRESS2_WSIZE, (const uint8_t*)in, in_size);
  buf[0] = buf[0] - 1;
  return ret;
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
    /* Websocket压缩/解压方法 */
    {"wscompress", lws_compress},
    {"wsuncompress", lws_uncompress},
    {NULL, NULL}
  };
  luaL_newlib(L, zlib_libs);
  return 1;
}
