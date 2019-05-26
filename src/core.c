#include "core.h"

/* ===========  Timer  =========== */
void
core_timer_init(core_timer *timer, _TIMER_CB cb){

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

	timer->repeat = timer->at = 0x0;

	ev_timer_again(loop ? loop : CORE_LOOP, timer);

}
/* ===========  Timer  =========== */




/* ===========  IO  =========== */
void
core_io_init(core_io *io, _IO_CB cb, int fd, int events){

	ev_io_init(io, cb, fd, events);

}

void
core_io_start(core_loop *loop, core_io *io){

	ev_io_start(loop ? loop : CORE_LOOP, io);

}

void
core_io_stop(core_loop *loop, core_io *io){

	if (io->events || io->fd){

		ev_io_stop(loop ? loop : CORE_LOOP, io);

		io->fd = io->events = 0x0;

	}

}
/* ===========  IO  =========== */


/* ===========  TASK  =========== */

void
core_task_init(core_task *task, _TASK_CB cb){

	ev_idle_init(task, cb);

}

void
core_task_start(core_loop *loop, core_task *task){

	ev_idle_start(loop ? loop : CORE_LOOP, task);

}

void
core_task_stop(core_loop *loop, core_task *task){

	ev_idle_stop(loop ? loop : CORE_LOOP, task);

}

/* ===========  TASK  =========== */


core_loop *
core_default_loop(){
	// 	ev_supported_backends() & EVBACKEND_EPOLL  || // Linux   使用 epoll
	// 	ev_supported_backends() & EVBACKEND_KQUEUE || // mac|BSD 使用 kqueue
	// 	ev_supported_backends() & EVBACKEND_SELECT || // other   使用 select
	// 	EVFLAG_AUTO								  	  // select  都没有就自动选择
	return ev_default_loop(ev_embeddable_backends() & ev_supported_backends() || EVFLAG_AUTO);
}

void
core_break(core_loop *loop, int mode){
	return ev_break(loop ? loop : CORE_LOOP, mode);
}


int
core_start(core_loop *loop, int mode){

	return ev_run(loop ? loop : CORE_LOOP, mode);

}

const char *signame[]= {
	"INVALID",
	"SIGHUP",
	"SIGINT",
	"SIGQUIT",
	"SIGILL",
	"SIGTRAP",
	"SIGABRT",
	"SIGBUS",
	"SIGFPE",
	"SIGKILL",
	"SIGUSR1",
	"SIGSEGV",
	"SIGUSR2",
	"SIGPIPE",
	"SIGALRM",
	"SIGTERM",
	"SIGSTKFLT",
	"SIGCHLD",
	"SIGCONT",
	"SIGSTOP",
	"SIGTSTP",
	"SIGTTIN",
	"SIGTTOU",
	"SIGURG",
	"SIGXCPU",
	"SIGXFSZ",
	"SIGVTALRM",
	"SIGPROF",
	"SIGWINCH",
	"SIGPOLL",
	"SIGPWR",
	"SIGSYS",
	NULL
};

#define signum_to_string(number) (signame[number])

static void // 忽略信号
SIG_IGNORE(core_loop *loop, core_signal *signal, int revents){
	// LOG("ERROR", signum_to_string(signal->signum));
	return ;
}

static void // 退出信号
SIG_EXIT(core_loop *loop, core_signal *signal, int revents){
	// LOG("ERROR", signum_to_string(signal->signum));
	return exit(-1);
}

static void
ERROR_CB(const char *msg){
	LOG("ERROR", msg);
	return ;
}

static void *
EV_ALLOC(void *ptr, long nsize){
	// 为libev内存hook注入日志;
	if (ptr && 0 > nsize){
		LOG("ERROR", "attemp to pass a negative number to malloc or free")
		return NULL;
	}
	if (nsize == 0) return xfree(ptr), NULL;
	for (;;) {
		void *newptr = xrealloc(ptr, nsize);
		if (newptr) return newptr;
		LOG("WARN", "Allocate failed, Sleep sometime..");
		sleep(1);
	}
}

static void *
L_ALLOC(void *ud, void *ptr, size_t osize, size_t nsize){
	// 为lua内存hook注入日志;
	/* 用户自定义数据 */
	(void)ud;  (void)osize;
	if (nsize == 0) return xfree(ptr), NULL;
	for (;;) {
		void *newptr = xrealloc(ptr, nsize);
		if (newptr) return newptr;
		LOG("WARN", "Allocate failed, Sleep sometime..");
		sleep(1);
	}
}

void
init_lua_libs(lua_State *L){
    /* lua 标准库 */
	luaL_openlibs(L);

	lua_pushglobaltable(L);
	lua_pushliteral(L, "null");
	lua_pushlightuserdata(L, NULL);
	lua_rawset(L, -3);
	lua_pushliteral(L, "NULL");
	lua_pushlightuserdata(L, NULL);
	lua_rawset(L, -3);

	lua_settop(L, 0);

	/* 注入lua搜索域 */
  lua_getglobal(L, "package");

  lua_pushliteral(L, "lualib/?.lua;lualib/?/init.lua;script/?.lua;script/?/init.lua;");
  lua_setfield(L, 1, "path");

  lua_pushliteral(L, "luaclib/?.so;luaclib/?/init.so;");
  lua_setfield(L, 1, "cpath");

  lua_settop(L, 0);
}

static lua_State *L;

/* 注册需要忽略的信号 */
core_signal sighup;
core_signal sigpipe;
core_signal sigtstp;

/* 注册需要退出的信号(docker需要) */
core_signal sigint;
core_signal sigterm;
core_signal sigquit;

void
signal_init(){

	/* 忽略父进程退出的信号 */
	ev_signal_init(&sighup, SIG_IGNORE, SIGHUP);
	ev_signal_start(CORE_LOOP_ &sighup);

	/* 忽略管道信号 */
	ev_signal_init(&sigpipe, SIG_IGNORE, SIGPIPE);
	ev_signal_start(CORE_LOOP_ &sigpipe);

	/* 忽略Ctrl-Z操作信号 */
	ev_signal_init(&sigtstp, SIG_IGNORE, SIGTSTP);
	ev_signal_start(CORE_LOOP_ &sigtstp);

	/* TERM信号 显示退出 */
	ev_signal_init(&sigterm, SIG_EXIT, SIGTERM);
	ev_signal_start(CORE_LOOP_ &sigterm);

	/* INT信号 显示退出 */
	ev_signal_init(&sigint, SIG_EXIT, SIGINT);
	ev_signal_start(CORE_LOOP_ &sigint);

	/* QUIT信号 显示退出 */
	ev_signal_init(&sigquit, SIG_EXIT, SIGQUIT);
	ev_signal_start(CORE_LOOP_ &sigquit);

}

void
init_main(){

	int status;
	L = lua_newstate(L_ALLOC, NULL);
	if (!L) return ;

	init_lua_libs(L);

	status = luaL_loadfile(L, "script/main.lua");

	// 停止GC
	lua_gc(L, LUA_GCSTOP, 0);

	// 设置 GC间歇率 = 每次开启一次新的GC所需的等待时间与条件; 默认为：200
	// lua_gc(L, LUA_GCSETPAUSE, 200);

	// 设置 GC步进率倍率 = 控制垃圾收集器相对于内存分配速度的倍数; 默认为：200
	// lua_gc(L, LUA_GCSETSTEPMUL, 200);

	if(status != LUA_OK) {
		switch(status){
			case LUA_ERRFILE :
				LOG("ERROR", "Can't find file or load file Error.");
				exit(-1);
			case LUA_ERRSYNTAX:
				LOG("ERROR", lua_tostring(L, -1));
				exit(-1);
			case LUA_ERRMEM:
				LOG("ERROR", "Memory Allocated faild.");
				exit(-1);
			case LUA_ERRGCMM:
				LOG("ERROR", "An Error from lua GC Machine.");
				exit(-1);
		}
		return ;
	}

	status = lua_resume(L, NULL, 0);
	if (status > 1){
		LOG("ERROR", lua_tostring(L, -1));
		return lua_close(L), exit(-1);
	}
	if (status == LUA_YIELD) {
		signal_init();
	}
	/* 重启GC */
	lua_gc(L, LUA_GCRESTART, 0);
}

void
core_sys_init(){

	/* hook libev 内存分配 */
	ev_set_allocator(EV_ALLOC);

	/* hook 事件循环错误信息 */
	ev_set_syserr_cb(ERROR_CB);

	/* 初始化Lua脚本 */
	init_main();

}

int
core_sys_run(){
	return core_start(CORE_LOOP_ 0);
}
