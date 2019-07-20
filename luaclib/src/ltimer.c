#define LUA_LIB

#include "../../src/core.h"

/* === 定时器 === */
static void
TIMEOUT_CB(CORE_P_ core_timer *timer, int revents){

    if (revents & EV_TIMER){

      lua_State *co = (lua_State *) core_get_watcher_userdata(timer);

      int status = CO_RESUME(co, NULL, lua_gettop(co) > 0 ? lua_gettop(co) - 1 : 0);

      if (status != LUA_OK && status != LUA_YIELD){

      	LOG( "ERROR", lua_tostring(co, -1));

  		  core_timer_stop(CORE_LOOP_ timer);

      }
    }
}

static int
timer_stop(lua_State *L){

	core_timer *timer = (core_timer *) luaL_testudata(L, 1, "__TIMER__");
	if(!timer) return 0;

	core_timer_stop(CORE_LOOP_ timer);

	return 0;
}

static int
timer_start(lua_State *L){

	core_timer *timer = (core_timer *) luaL_testudata(L, 1, "__TIMER__");
	if(!timer) return 0;

	lua_Number timeout = luaL_checknumber(L, 2);
    if (timeout <= 0 ) return 0;

	lua_State *co = lua_tothread(L, 3);
	if(!co) return 0;

	core_set_watcher_userdata(timer, (void*)co);

	core_timer_start(CORE_LOOP, timer, timeout);

	return 0;

}

static int
timer_new(lua_State *L){

	core_timer *timer = (core_timer *) lua_newuserdata(L, sizeof(core_timer));
	if(!timer) return 0;

	core_timer_init(timer, TIMEOUT_CB);

	luaL_setmetatable(L, "__TIMER__");

	return 1;

}

LUAMOD_API int
luaopen_timer(lua_State *L){
	luaL_checkversion(L);
  luaL_newmetatable(L, "__TIMER__");
  lua_pushstring (L, "__index");
  lua_pushvalue(L, -2);
  lua_rawset(L, -3);
  lua_pushliteral(L, "__mode");
  lua_pushliteral(L, "kv");
  lua_rawset(L, -3);
	luaL_Reg timer_libs[] = {
		{"new",   	timer_new},
		{"stop",  	timer_stop},
		{"start", 	timer_start},
		{NULL, NULL},
	};
  luaL_setfuncs(L, timer_libs, 0);
	luaL_newlib(L, timer_libs);
  return 1;
}
