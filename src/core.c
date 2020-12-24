#include "core.h"

#define LUALIBS_PATH \
	"lualib/?.lua;;lualib/?/init.lua;;" \
	"3rd/?.lua;;3rd/?/init.lua;;" \
	"script/?.lua;;script/?/init.lua;;"

#define LUACLIBS_PATH \
	"luaclib/?.so;;luaclib/lib?.so;;"         \
	"luaclib/?.dylib;;luaclib/lib?.dylib;;"   \
	"luaclib/?.dll;;luaclib/msys-?.dll;;"     \
																						\
	"./?.so;;./lib?.so;;"                     \
	"./?.dylib;;./lib?.dylib;;"               \
	"./?.dll;;./msys-?.dll;;"									\
																						\
  "3rd/?.so;;3rd/lib?.so;;"									\
  "3rd/?.dylib;3rd/lib?.dylib;;"						\
  "3rd/?.dll;;3rd/msys-?.dll;;"

/* 忽略信号 */
static void SIG_IGNORE(core_loop *loop, core_signal *signal, int revents){
	// LOG("ERROR", signum_to_string(signal->signum));
	return ;
}

/* 退出信号 */
static void SIG_EXIT(core_loop *loop, core_signal *signal, int revents){
	// LOG("ERROR", signum_to_string(signal->signum));
	if (ev_userdata(loop) && core_get_watcher_userdata(signal)) {
		int index;
		pid_t *pids = (pid_t *)ev_userdata(loop);
		int pidcount = *(int*)core_get_watcher_userdata(signal);
		for (index = 0; index < pidcount; index++) {
			pid_t pid = pids[index];
			if (pid > 0)
				kill(pid, SIGKILL);
		}
	}
	_exit(-1);
	return ;
}

static void ERROR_CB(const char *msg){
	LOG("ERROR", msg);
	return ;
}

static void *EV_ALLOC(void *ptr, long nsize){
	// 为libev内存hook注入日志;
	if (nsize == 0) return xfree(ptr), NULL;
	for (;;) {
		void *newptr = xrealloc(ptr, nsize);
		if (newptr) return newptr;
		LOG("WARN", "Allocate failed, Sleep sometime..");
		sleep(1);
	}
}

static void* L_ALLOC(void *ud, void *ptr, size_t osize, size_t nsize){
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

void init_lua_libs(lua_State *L){
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

	/* 注入lualib搜索路径 */
  lua_pushliteral(L, LUALIBS_PATH);
  lua_setfield(L, 1, "path");

	/* 注入luaclib搜索路径 */
	lua_pushliteral(L, LUACLIBS_PATH);
  lua_setfield(L, 1, "cpath");

  lua_settop(L, 0);
}

/* 注册需要忽略的信号 */
core_signal sighup;
core_signal sigpipe;
core_signal sigtstp;

/* 注册需要退出的信号(docker需要) */
core_signal sigint;
core_signal sigterm;
core_signal sigquit;

void signal_init(int* workers){

	/* 忽略父进程退出的信号 */
	core_signal_init(&sighup, SIG_IGNORE, SIGHUP);
	core_signal_start(CORE_LOOP_ &sighup);

	/* 忽略管道信号 */
	core_signal_init(&sigpipe, SIG_IGNORE, SIGPIPE);
	core_signal_start(CORE_LOOP_ &sigpipe);

	/* 忽略Ctrl-Z操作信号 */
	core_signal_init(&sigtstp, SIG_IGNORE, SIGTSTP);
	core_signal_start(CORE_LOOP_ &sigtstp);

	/* TERM信号 显示退出 */
	core_signal_init(&sigterm, SIG_EXIT, SIGTERM);
	core_signal_start(CORE_LOOP_ &sigterm);
	if (workers)
		core_set_watcher_userdata(&sigterm, workers);
	/* INT信号 显示退出 */
	core_signal_init(&sigint, SIG_EXIT, SIGINT);
	core_signal_start(CORE_LOOP_ &sigint);
	if (workers)
		core_set_watcher_userdata(&sigint, workers);

	/* QUIT信号 显示退出 */
	core_signal_init(&sigquit, SIG_EXIT, SIGQUIT);
	core_signal_start(CORE_LOOP_ &sigquit);
	if (workers)
		core_set_watcher_userdata(&sigquit, workers);

}

int core_slave_run(const char entry[]) {
	core_loop *loop = core_loop_fork(core_default_loop());

	int status = 0;

	lua_State *L = lua_newstate(L_ALLOC, NULL);
	if (!L)
		exit(-1);

	init_lua_libs(L);

	CO_GCRESET(L);

	status = luaL_loadfile(L, entry);
	if (status > 1){
		LOG("ERROR", lua_tostring(L, -1));
		lua_close(L);
		exit(-1);
	}

	status = CO_RESUME(L, NULL, 0);
	if (status > 1){
		LOG("ERROR", lua_tostring(L, -1));
		lua_close(L);
		_exit(-1);
	}

	if (status == LUA_YIELD)
		signal_init(NULL);

	return core_start(loop, 0);
}

int core_master_run(int *pids[], int* pidcount) {
	/* 初始化信号 */ 
	signal_init(pidcount);
	/* 设置pid */ 
	ev_set_userdata(core_default_loop(), pids);
	/* 初始化主进程 */ 
	return core_start(core_loop_fork(core_default_loop()), 0);
}

int core_run(const char entry[], int workers) {
	/* hook libev 内存分配 */
	core_ev_set_allocator(EV_ALLOC);
	/* hook 事件循环错误信息 */
	core_ev_set_syserr_cb(ERROR_CB);
	/* 初始化进程 */
#if defined(__MSYS__)
	/* Windows下不可使用多进程 */
	workers = 1;
#endif
	pid_t pids[workers];
	int i;
  for (i = 0; i < workers; i++) {
		int pid = fork();
		if (pid == 0){
			return core_slave_run(entry);
		} else if (pid < 0) {
			LOG("ERROR", "Create Process Error.");
			_exit(-1);
		}	
		pids[i] = pid;
  }
	return core_master_run((pid_t **)&pids, &workers);
}
