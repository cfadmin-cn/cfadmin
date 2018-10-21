#include "core.h"

lua_State *L;

void
init_main(EV_ONCE_ void *args, int revents){
	L = luaL_newstate();
	if (!L) return ;
	luaL_openlibs(L);
	
	/* 注入socket模块 */
	luaL_newlib(L, socket_libs);
	lua_setglobal(L,"core_socket");

	/* 注入timer模块 */
	luaL_newlib(L, timer_libs);
	lua_setglobal(L,"core_timer");

	// lua_gc(L, LUA_GCSTOP, 0);
	char *lib  = "./lualib/?.lua;./?.lua;./script/?.lua;" ;
	char *clib = "./luaclib/?.so;./lualib/?.so;./script/?.so" ;

	lua_getglobal(L, "package");

	lua_pushstring(L, lib);
	lua_setfield(L, 1, "path");

	lua_pushstring(L, clib);
	lua_setfield(L, 1, "cpath");

	luaL_loadfile(L, "script/main.lua");
	int status = lua_pcall(L, 0, LUA_MULTRET, 0);
	if (status > 1){
		LOG("INFO", lua_tostring(L, -1));
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