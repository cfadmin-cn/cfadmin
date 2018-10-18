#include "core.h"

lua_State *main_co;

void
init_main(int revents, void *args){
	main_co = luaL_newstate();
	if (!main_co) return ;
	lua_openlibs(main_co);

	lua_gc(main_co, LUA_GCSTOP, 0);

	luaL_loadfile(main_co, "script/main.lua");
	int status = lua_pcall(main_co, 0, LUA_MULTRET, 0);
	if (status > 1){
		LOG("INFO", lua_tostring(main_co, -1));
	}
}


void
core_sys_init(){
	/* hook内存分配 */
	ev_set_allocator(realloc);
	/* 初始化script */
	ev_once(-1, 0, 0, init_main, NULL);
}

int
main(int argc, char const *argv[])
{
	/* 系统初始化 */
	core_sys_init();

	/* 事件循环 */
	ev_run(EV_DEFAULT_ EVFLAG_AUTO);
	return 0;
}