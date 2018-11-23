#ifndef __CORE_LOOP__
#define __CORE_LOOP__

#include "../src/core_sys.h"
#include "../src/core_memory.h"
#include "../src/core_ev.h"

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

int loop_run(lua_State *L);

int luaopen_loop(lua_State *L);

static const luaL_Reg loop_libs[] = {
	{"run", loop_run},
	{NULL, NULL}
};

#endif