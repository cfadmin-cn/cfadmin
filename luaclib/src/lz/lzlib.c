#define LUA_LIB

#include "../../../src/core.h"
#include <zlib.h>


static inline
void stream_init(z_stream *z) {
  memset(z, 0x0, sizeof(*z));
  z->zalloc = Z_NULL;
  z->zfree = Z_NULL;
  z->opaque = Z_NULL;
}

// static int lcompress(lua_State *L) {
//   return 1;
// }

// static int luncompress(lua_State *L) {
//   return 1;
// }

static int lgzip_compress(lua_State *L) {
  size_t in_size = 0;
  const char* in = luaL_checklstring(L, 1, &in_size);
  if (in_size <= 0)
    return 0;

  z_stream z;
  stream_init(&z);

  int ok = deflateInit2(&z, Z_DEFAULT_COMPRESSION, Z_DEFLATED, MAX_WBITS + 16, 8, Z_DEFAULT_STRATEGY);
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
    inflateReset(&z);
    out_size <<= 1;
    luaL_pushresultsize(&B, 0);
    lua_settop(L, top);
  }
  return 1;
}

LUAMOD_API int
luaopen_lz(lua_State *L){
  luaL_checkversion(L);
  luaL_Reg zlib_libs[] = {
    // {"compress", lcompress},
    // {"uncompress", luncompress},    
    {"gzcompress", lgzip_compress},
    {"gzuncompress", lgzip_uncompress},
    {NULL, NULL}
  };
  luaL_newlib(L, zlib_libs);
  return 1;
}