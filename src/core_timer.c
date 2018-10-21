#include "core_socket.h"

/* === 定时器 === */
void
timeout_cb(EV_P_ ev_timer *timer, int revents){
	if (ev_have_watcher_userdata(timer)){
		lua_State *co = (lua_State *)ev_get_watcher_userdata(timer);
		int status = lua_resume(co, NULL, lua_gettop(co) > 0 ? lua_gettop(co) - 1 : 0);
	}
	ev_timer_stop(EV_DEFAULT_ timer);
	free(timer);
}

int
timer_timeout(lua_State *L){
	lua_Number timeout = lua_tonumber(L, 1);
	if (!timeout || 0. > timeout) return 1;
	
	if (lua_type(L, 2) != LUA_TFUNCTION) return 1;

	ev_timer *timer = malloc(sizeof(ev_timer));
	if (!timer) return 1;

	lua_State *co = lua_newthread(L);
	if (!timer) return 1;

	lua_pop(L, 1);

	lua_xmove(L, co, 1);

	ev_set_watcher_userdata(timer, co);

	ev_timer_init(timer, timeout_cb, timeout, 0);

	ev_timer_start(EV_DEFAULT_ timer);
	
	lua_settop(L, 0);
	return 0;
}