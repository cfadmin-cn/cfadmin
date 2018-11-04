#ifndef __CORE_SOCKET__
#define __CORE_SOCKET__

#include "../src/core_sys.h"
#include "../src/core_memory.h"
#include "../src/core_ev.h"

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

#define SERVER 0
#define CLIENT 1

int io_get_fd(lua_State *L);

int io_new_tcp_fd(lua_State *L);

int io_new(lua_State *L);

int io_stop(lua_State *L);

int io_listen(lua_State *L);

int io_connect(lua_State *L);

int io_start(lua_State *L);

int io_close(lua_State *L);

int io_read(lua_State *L);

int io_write(lua_State *L);

static const luaL_Reg socket_libs[] = {
	{"read", io_read},
	{"write", io_write},
	{"new", io_new},
	{"stop", io_stop},
	{"start", io_start},
	{"close", io_close},
	{"listen", io_listen},
	{"connect", io_connect},
	{"get_fd", io_get_fd},
	{"new_tcp_fd", io_new_tcp_fd},
	{NULL, NULL}
};

#endif