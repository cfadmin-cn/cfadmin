#ifndef __CORE_UDP__
#define __CORE_UDP__

#include "../src/core_sys.h"
#include "../src/core_memory.h"
#include "../src/core_ev.h"

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

int new_udp_fd(lua_State *L);

int udp_new(lua_State *L);

int udp_close(lua_State *L);

int udp_connect(lua_State *L);

int udp_stop(lua_State *L);

int udp_close(lua_State *L);


static const luaL_Reg udp_libs[] = {
	{"new", udp_new},
	{"close", udp_close},
	{"connect", udp_connect},
	{"new_udp_fd", new_udp_fd},
	{NULL, NULL}
};

#endif