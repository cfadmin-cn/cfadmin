#include "core.h"

lua_State *L;

void
init_main(EV_ONCE_ void *args, int revents){
	int status;
	L = luaL_newstate();
	if (!L) return ;
	luaL_openlibs(L);

    // /* 注入搜索域 */
    char *lib  = "./lualib/?.lua;./?.lua;./script/?.lua;" ;
    char *clib = "./luaclib/?.so;./lualib/?.so;./script/?.so" ;

    lua_getglobal(L, "package");

    lua_pushstring(L, lib);
    lua_setfield(L, 1, "path");

    lua_pushstring(L, clib);
    lua_setfield(L, 1, "cpath");

    /* 注入socket模块 */
	luaL_newmetatable(L, "__IO__");
	lua_pushstring (L, "__index");
	lua_pushvalue(L, -2);
	lua_rawset(L, -3);
	luaL_setfuncs(L, socket_libs,0);
	luaL_newlib(L, socket_libs);
	lua_setglobal(L, "core_socket");

    /* 注入timer模块 */
    luaL_newmetatable(L, "__TIMER__");
    lua_pushstring (L, "__index");
    lua_pushvalue(L, -2);
    lua_rawset(L, -3);
    luaL_setfuncs(L, timer_libs,0);
    luaL_newlib(L, timer_libs);
    lua_setglobal(L, "core_timer");

	status = luaL_loadfile(L, "script/main.lua");
	if(status != LUA_OK) {
		switch(status){
			case LUA_ERRFILE :
				LOG("ERROR", "找不到文件或无法读取文件.");
				break;
			case LUA_ERRSYNTAX:
				LOG("ERROR", lua_tostring(L, -1));
				break;
			case LUA_ERRMEM:
				LOG("ERROR", "内存分配失败.");
				break;
			case LUA_ERRGCMM:
				LOG("ERROR", "__gc方法失败.");
				break;
		}
		ev_break (EV_DEFAULT_ EVBREAK_ALL);
		return ;
	}
	status = lua_pcall(L, 0, LUA_MULTRET, 0);
	if (status > 1){
		LOG("ERROR", lua_tostring(L, -1));
		ev_break (EV_DEFAULT_ EVBREAK_ALL);
	}

	lua_gc(L, LUA_GCCOLLECT, 0);
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