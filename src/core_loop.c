#include "core_loop.h"

int
loop_run(lua_State *L){
	return ev_run(EV_LOOP_ 0);
}


int
luaopen_loop(lua_State *L){
	luaL_newmetatable(L, "__LOOP__");
	lua_pushstring (L, "__index");
	lua_pushvalue(L, -2);
	lua_rawset(L, -3);
	luaL_setfuncs(L, loop_libs, 0);
	luaL_newlib(L, loop_libs);
	lua_setglobal(L, "core_loop");
	return 1;
}