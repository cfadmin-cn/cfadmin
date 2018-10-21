#ifndef __CORE_SOCKET__
#define __CORE_SOCKET__

#include "core_sys.h"
#include "core_memory.h"
#include "core_ev.h"

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

int io_recv(lua_State *L);

int io_send(lua_State *L);

int io_listen(lua_State *L);

static const luaL_Reg socket_libs[] = {
	{"listen", io_listen},
	{"send", io_send},
	{"recv", io_recv},
	{NULL, NULL}
};

#endif