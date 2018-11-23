#ifndef __CORE_UDP__
#define __CORE_UDP__

#include "../src/core_sys.h"
#include "../src/core_memory.h"
#include "../src/core_ev.h"

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

int udp_new(lua_State *L);

int udp_close(lua_State *L);

int udp_connect(lua_State *L);

int udp_stop(lua_State *L);

int udp_start(lua_State *L);

int udp_recv(lua_State *L);

int udp_send(lua_State *L);

int luaopen_udp(lua_State *L);

static const luaL_Reg udp_libs[] = {
	{"new", udp_new},
	{"close", udp_close},
    {"start", udp_start},
    {"stop", udp_stop},
	{"connect", udp_connect},
    {"send", udp_send},
    {"recv", udp_recv},
	{NULL, NULL}
};

#endif