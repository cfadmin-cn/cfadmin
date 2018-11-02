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

int io_listen(lua_State *L);

int io_stop(lua_State *L);

int io_start(lua_State *L);

int io_close(lua_State *L);

int io_new(lua_State *L);

int io_read(lua_State *L);

int io_write(lua_State *L);

static const luaL_Reg socket_libs[] = {
	{"listen", io_listen},
	{"close", io_close},
	{"start", io_start},
	{"stop", io_stop},
	{"new", io_new},
	{"read", io_read},
	{"write", io_write},
	{NULL, NULL}
};

#endif