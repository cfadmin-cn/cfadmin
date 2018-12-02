#include "core.h"

void *
L_ALLOC(void *ud, void *ptr, size_t osize, size_t nsize){

	(void)ud;  (void)osize;  /* lua 不会使用 */

	if (nsize == 0) return realloc(ptr, nsize);

	return realloc(ptr, nsize);

}

void
init_lua_libs(lua_State *L){
    /* lua 标准库 */
	luaL_openlibs(L);

	/* 注入搜索域 */
    char *lib  = "./lualib/?.lua;./?.lua;./script/?.lua;" ;
    char *clib = "./luaclib/?.so;./lualib/?.so;./script/?.so" ;

    lua_getglobal(L, "package");

    lua_pushstring(L, lib);
    lua_setfield(L, 1, "path");

    lua_pushstring(L, clib);
    lua_setfield(L, 1, "cpath");

    /* 注入TCP模块 */
    luaopen_tcp(L);

    /* 注入UDP模块 */
	luaopen_udp(L);

    /* 注入Timer模块 */
	luaopen_timer(L);

    /* 注入Loop模块 */
	luaopen_loop(L);

}

void
init_main(){

	int status;
	lua_State *L = lua_newstate(L_ALLOC, NULL);
	if (!L) return ;

	init_lua_libs(L);

	status = luaL_loadfile(L, "script/main.lua");
	if(status != LUA_OK) {
		switch(status){
			case LUA_ERRFILE :
				LOG("ERROR", "Can't find file or load file Error.");
				break;
			case LUA_ERRSYNTAX:
				LOG("ERROR", lua_tostring(L, -1));
				break;
			case LUA_ERRMEM:
				LOG("ERROR", "Memory Allocated faild.");
				break;
			case LUA_ERRGCMM:
				LOG("ERROR", "An Error from lua GC Machine.");
				break;
		}
		ev_break (EV_LOOP_ EVBREAK_ALL);
		return ;
	}
	status = lua_resume(L, NULL, 0);
	if (status > 1){
		LOG("ERROR", lua_tostring(L, -1));
		ev_break (EV_LOOP_ EVBREAK_ALL);
	}
	lua_gc(L, LUA_GCCOLLECT, 0);
}


void
core_sys_init(){
	/* hook libev 内存分配 */
	ev_set_allocator(realloc);

	/* 初始化script */
	init_main();
}

int
main(int argc, char const *argv[])
{
	/* 系统初始化 */
	core_sys_init();

    ev_run(EV_LOOP_ 0);

	return 0;
}