#ifndef __CORE_TIMER__
#define __CORE_TIMER__

#include "core_sys.h"
#include "core_memory.h"
#include "core_ev.h"

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

/* 创建定时器 */
int timer_new(lua_State *L);

/* 停止定时器 */
int timer_stop(lua_State *L);

/* 启动定时器 */
int timer_start(lua_State *L);

const luaL_Reg timer_libs[] = {
	{"new",   timer_new},
	{"stop",  timer_stop},
	{"start", timer_start},
	{NULL, NULL}
};

#endif