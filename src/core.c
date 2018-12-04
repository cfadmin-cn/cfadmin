#include "core.h"


/* ===========  Timer  =========== */
void
core_timer_init(core_timer *timer, TIMER_CB cb){

	timer->repeat = timer->at = 0x0;

	ev_init(timer, cb);

}

void
core_timer_start(core_loop *loop, core_timer *timer, ev_tstamp timeout){

	timer->repeat = timeout;

	ev_timer_again(loop ? loop : CORE_LOOP, timer);

}

void
core_timer_stop(core_loop *loop, core_timer *timer){

	timer->repeat = timer->at = 0;

	ev_timer_again(loop ? loop : CORE_LOOP, timer);

}
/* ===========  Timer  =========== */




/* ===========  IO  =========== */
void
core_io_init(core_io *io, IO_CB cb, int fd, int events){

	ev_io_init(io, cb, fd, events);

}

void
core_io_start(core_loop *loop, core_io *io){

	ev_io_start(loop ? loop : CORE_LOOP, io);

}

void
core_io_stop(core_loop *loop, core_io *io){  

	ev_io_stop(loop ? loop : CORE_LOOP, io);

	io->fd = io->events = 0x0;

}
/* ===========  IO  =========== */

core_loop *
core_default_loop(){

	// return ev_default_loop(flags ? flags : ev_supported_backends() & EVBACKEND_EPOLL || ev_supported_backends() & EVBACKEND_KQUEUE);
	return ev_default_loop(ev_supported_backends() & EVBACKEND_EPOLL || ev_supported_backends() & EVBACKEND_KQUEUE);

}

int
core_start(core_loop *loop, int mode){

	return ev_run(loop ? loop : CORE_LOOP, mode);

}



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
    char *lib  = "./lualib/?.lua;./script/?.lua;" ;
    char *clib = "./luaclib/?.so;./script/?.so;" ;

    lua_getglobal(L, "package");

    lua_pushstring(L, lib);
    lua_setfield(L, 1, "path");

    lua_pushstring(L, clib);
    lua_setfield(L, 1, "cpath");

    lua_settop(L, 0);

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
		return ;
	}
	status = lua_resume(L, NULL, 0);
	if (status > 1){
		LOG("ERROR", lua_tostring(L, -1));
		return ;
	}
	lua_gc(L, LUA_GCCOLLECT, 0);
}

void
core_sys_init(){
	/* hook libev 内存分配 */
	ev_set_allocator(xrealloc);

	/* 初始化script */
	init_main();
}

int
core_sys_run(){

	return core_start(CORE_LOOP_ 0);
}



