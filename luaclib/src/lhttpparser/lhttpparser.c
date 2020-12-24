#define LUA_LIB

#include <core.h>
#include "httpparser.h"

#define MAX_HEADER (128)

static int
lparser_response_chunked(lua_State *L){
  size_t buf_len;
  const char* data = luaL_checklstring(L, 1, &buf_len);

  char *buf = (buf_len < 65535) ? alloca(1 << 16) : lua_newuserdata(L, buf_len);
  memcpy(buf, data, buf_len);

  struct phr_chunked_decoder decoder = { .consume_trailer = 1 };

  int last = phr_decode_chunked(&decoder, buf, &buf_len);
  if (last >= 0) {
    lua_pushlstring(L, (const char *)buf, buf_len);
    return 1;
  }
  lua_pushnil(L);
  lua_pushinteger(L, last);
  return 2;
}

static int
lparser_http_request(lua_State *L){
  size_t buf_len;
  const char* buf = luaL_checklstring(L, 1, &buf_len);

  int minor_version, ret, i;
  const char *method;
  const char *path;
  size_t method_len, path_len, num_headers;

  struct phr_header headers[MAX_HEADER];
  memset(headers, 0x0, sizeof(struct phr_header) * MAX_HEADER);

  num_headers = MAX_HEADER;
  ret = phr_parse_request(buf, buf_len, &method, &method_len, &path, &path_len, &minor_version, headers, &num_headers, 0);
  if (0 > ret) return 0;

  lua_pushlstring(L, method, method_len); // METHOD
  lua_pushlstring(L, path, path_len);  // PATH
  lua_pushnumber(L, minor_version > 0 ? 1.1 : 1.0); // VERSION

  lua_createtable(L, 0, MAX_HEADER);
  for (i = 0; i < MAX_HEADER; i++){
    if (!headers[i].name || !headers[i].value)
      break;
    lua_pushlstring(L, headers[i].name, headers[i].name_len);
    lua_pushlstring(L, headers[i].value, headers[i].value_len);
    lua_rawset(L, lua_gettop(L) - 2);
  }
  return 4;
}

static int
lparser_http_response(lua_State *L){
  size_t buf_len;
  const char* buf = luaL_checklstring(L, 1, &buf_len);

  int status, minor_version, ret, i;
  size_t msg_len, num_headers;
  const char* msg;

  struct phr_header headers[MAX_HEADER];
  memset(headers, 0x0, sizeof(struct phr_header) * MAX_HEADER);

  num_headers = MAX_HEADER;
  ret = phr_parse_response(buf, buf_len, &minor_version, &status, &msg, &msg_len, headers, &num_headers, 0);
  if (0 > ret) return 0;

  lua_pushnumber(L, minor_version > 0 ? 1.1 : 1.0); // VERSION
  lua_pushinteger(L, status); // STATUS CODE
  lua_pushlstring(L, msg, msg_len);  // STATUS MSG

  lua_createtable(L, 0, MAX_HEADER);
  for (i = 0; i < MAX_HEADER; i++){
    if (!headers[i].name || !headers[i].value)
      break;
    lua_pushlstring(L, headers[i].name, headers[i].name_len);
    lua_pushlstring(L, headers[i].value, headers[i].value_len);
    lua_rawset(L, lua_gettop(L) - 2);
  }
  return 4;
}

LUAMOD_API int
luaopen_httpparser(lua_State *L) {
    luaL_checkversion(L);
    luaL_Reg httpparser_libs[] = {
      {"parser_response_chunked", lparser_response_chunked},
      {"parser_http_request", lparser_http_request},
      {"parser_http_response", lparser_http_response},
      {NULL, NULL}
    };
    luaL_newlib(L, httpparser_libs);
    return 1;
}
