#ifndef __CORE_TCP__
#define __CORE_TCP__

#include "../src/core_sys.h"
#include "../src/core_memory.h"
#include "../src/core_ev.h"

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

#define SERVER 0
#define CLIENT 1

int new_tcp_fd(lua_State *L);

int tcp_get_fd(lua_State *L);

int tcp_new(lua_State *L);

int tcp_stop(lua_State *L);

int tcp_listen(lua_State *L);

int tcp_connect(lua_State *L);

int tcp_start(lua_State *L);

int tcp_close(lua_State *L);

int tcp_readall(lua_State *L);

int tcp_read(lua_State *L);

int tcp_write(lua_State *L);

int luaopen_tcp(lua_State *L);

static const luaL_Reg tcp_libs[] = {
	{"read", tcp_read},
	{"readall", tcp_readall},
	{"write", tcp_write},
	{"new", tcp_new},
	{"stop", tcp_stop},
	{"start", tcp_start},
	{"close", tcp_close},
	{"listen", tcp_listen},
	{"connect", tcp_connect},
	{"get_fd", tcp_get_fd},
	{"new_tcp_fd", new_tcp_fd},
	{NULL, NULL}
};

#endif