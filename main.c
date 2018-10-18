#include "stdio.h"
#include "ev.h"

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
lua_State *L;
lua_State *t;
ev_timer timer;

void
timer_cb(EV_P_ ev_timer *timer, int revents){
	t = lua_newthread(L);
	lua_getglobal(t, "test");
	printf("top = %d\n", lua_gettop(t));
	lua_resume(t, NULL, lua_gettop(t) > 1 ? lua_gettop(t) -1 : 0);
}

int main(int argc, char const *argv[])
{
	L = luaL_newstate();
	luaL_openlibs(L);
	luaL_dofile(L, "test.lua");

	ev_timer_init(&timer, timer_cb, 1, 1);
	ev_timer_start(EV_DEFAULT_ &timer);

	return ev_run(EV_DEFAULT_ 0);
}