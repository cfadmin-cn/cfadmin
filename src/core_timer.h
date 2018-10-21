#ifndef __CORE_TIMER__
#define __CORE_TIMER__

#include "core_sys.h"
#include "core_memory.h"
#include "core_ev.h"

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

int timer_timeout(lua_State *L);

static const luaL_Reg timer_libs[] = {
	{"timeout", timer_timeout},
	{NULL, NULL}
};

#endif