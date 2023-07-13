#include "core.h"

#define MASTER (1)
#define WORKER (2)
#define IS_MASTER(mode) (mode == MASTER)
#define IS_WORKER(mode) (mode == WORKER)

#define LUALIBS_PATH \
  "lualib/?.lua;;lualib/?/init.lua;;"       \
  "lualib/?.lc;;lualib/?/init.lc;;"         \
  \
  "3rd/?.lua;;3rd/?/init.lua;;"             \
  "3rd/?.lc;;3rd/?/init.lc;;"               \
  \
  "script/?.lua;;script/?/init.lua;;"       \
  "script/?.lc;;script/?/init.lc;;"


#define LUACLIBS_PATH \
  "luaclib/?.so;;luaclib/lib?.so;;"         \
  "3rd/?.so;;3rd/lib?.so;;"                 \
  \
  "3rd/?.dylib;;3rd/lib?.dylib;;"           \
  "luaclib/?.dylib;;luaclib/lib?.dylib;;"   \
  \
  "luaclib/?.dll;;luaclib/msys-?.dll;;"     \
  "3rd/?.dll;;3rd/msys-?.dll;;"

/* Master 进程 `Main`函数 */
static const char* master_boot = "\n\
local process = require 'process.master'\n\
\
process.init(...)\n\
\
local f = loadfile('script/boot.lua')\n\
\
if f then\n\
\
  require 'cf'.fork(f)\n\
\
end\n\
require 'cf'.wait()\n\
";

/* Worker 进程 `Main`函数 */
static const char* worker_boot = "\n\
local process = require 'process.worker'\n\
\
process.init()\n\
\
local f = assert(loadfile(...))\n\
\
require 'cf'.fork(f)\n\
\
require 'cf'.wait()\n\
";

static lua_State *L = NULL;

/* 打印堆栈 */
static void SIG_DUMP(int signo){
  // printf("收到信号\n");
  if (!L)
    return;

  int top = lua_gettop(L);
  if (lua_getfield(L, LUA_REGISTRYINDEX, "co") != LUA_TTHREAD)
    return lua_settop(L, top);

  luaL_traceback(L, lua_tothread(L, -1), NULL, 0);
  printf("\n===========Lua Stack===========\n");
  printf("%s", lua_tostring(L, -1));
  printf("\n===========Lua Stack===========\n");

  return lua_settop(L, top);
}

/* 忽略信号 */
static void SIG_IGNORE(core_loop *loop, core_signal *signal, int revents){
  (void)loop; (void)signal; (void)revents;
  return ;
}

/* 退出信号 */
static void SIG_EXIT(core_loop *loop, core_signal *signal, int revents){
  (void)signal; (void)revents;
  /* 只有主进程退出的时候才需要通知子进程退出 */
  if (ev_userdata(loop))
    kill(0, SIGQUIT);
  return exit(EXIT_SUCCESS);
}

/* 内部异常 */
static void EV_ERROR_CB(const char *msg){
  LOG("ERROR", msg);
  LOG("ERROR", strerror(errno));
  if (CORE_LOOP) {
    pid_t *pids = (pid_t *)ev_userdata(CORE_LOOP);
    if (pids)
      kill(0, SIGKILL);
  }
  /* 减少无效打印, 专注错误提示 */
  return exit(EXIT_SUCCESS);
}

/* 为libev内存hook注入日志 */
static void *EV_ALLOC(void *ptr, long nsize){
  if (nsize == 0) return xfree(ptr), NULL;
  for (;;) {
    void *newptr = xrealloc(ptr, nsize);
    if (newptr) return newptr;
    LOG("WARN", "Allocate failed, Sleep sometime..");
    sleep(1);
  }
}

/* 为lua内存hook注入日志 */
static void* L_ALLOC(void *ud, void *ptr, size_t osize, size_t nsize){
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

void init_lua_mode(lua_State *L, int mode) {
  /* worker */
  if (IS_WORKER(mode) && getenv("cfadmin_isWorker")) {
    lua_pushliteral(L, "worker");
    lua_createtable(L, 0, 0);
    lua_pushliteral(L, "id");
    lua_pushinteger(L, getpid() - getppid());
    lua_rawset(L, -3);
    lua_pushliteral(L, "pid");
    lua_pushinteger(L, getpid());
    lua_rawset(L, -3);
    lua_pushliteral(L, "ppid");
    lua_pushinteger(L, getppid());
    lua_rawset(L, -3);
    lua_pushliteral(L, "nprocess");
    lua_pushinteger(L, atoi(getenv("cfadmin_nprocess")));
    lua_rawset(L, -3);
    lua_rawset(L, -3);
  /* Master */
  } else if (IS_MASTER(mode)) {
    lua_pushliteral(L, "master");
    lua_createtable(L, 0, 0);
    lua_pushliteral(L, "pid");
    lua_pushinteger(L, getpid());
    lua_rawset(L, -3);
    lua_pushliteral(L, "nprocess");
    lua_pushinteger(L, atoi(getenv("cfadmin_nprocess")));
    lua_rawset(L, -3);
    lua_rawset(L, -3);
  }
}

void init_lua_libs(lua_State *L, int mode){
  /* lua 标准库 */
  luaL_openlibs(L);

  // 获取全局表
  lua_pushglobaltable(L);
  // 将我可能被运行的文件名放置到全局表
  lua_pushliteral(L, " return 'Hello world.' ");
  lua_setfield(L, -2, "mycode");

  lua_pushliteral(L, "null");
  lua_pushlightuserdata(L, NULL);
  lua_rawset(L, -3);
  lua_pushliteral(L, "NULL");
  lua_pushlightuserdata(L, NULL);
  lua_rawset(L, -3);

  /*注入*/
  init_lua_mode(L, mode);

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

  /* 优化Lua的GC */
  CO_GCRESET(L);
}

/* 注册需要忽略的信号 */
core_signal sighup;
core_signal sigpipe;
core_signal sigtstp;

/* 注册需要退出的信号(docker需要) */
core_signal sigint;
core_signal sigterm;
core_signal sigquit;

static inline void signal_init(){

  signal(SIGUSR1, SIG_DUMP);
  signal(SIGUSR2, SIG_DUMP);

  /* 忽略连接中断信号 */
  core_signal_init(&sighup, SIG_IGNORE, SIGHUP);
  core_signal_start(CORE_LOOP_ &sighup);

  /* 忽略无效的管道读/写信号 */
  core_signal_init(&sigpipe, SIG_IGNORE, SIGPIPE);
  core_signal_start(CORE_LOOP_ &sigpipe);

  /* 忽略Ctrl-Z操作信号 */
  core_signal_init(&sigtstp, SIG_IGNORE, SIGTSTP);
  core_signal_start(CORE_LOOP_ &sigtstp);

  if (ev_userdata(CORE_LOOP)) {

    /* TERM信号 显示退出 */
    core_signal_init(&sigterm, SIG_EXIT, SIGTERM);
    core_signal_start(CORE_LOOP_ &sigterm);

    /* INT信号 显示退出 */
    core_signal_init(&sigint, SIG_EXIT, SIGINT);
    core_signal_start(CORE_LOOP_ &sigint);

    /* QUIT信号 显示退出 */
    core_signal_init(&sigquit, SIG_EXIT, SIGQUIT);
    core_signal_start(CORE_LOOP_ &sigquit);

  }
}

int core_worker_run(const char entry[]) {
  /* hook libev 内存分配 */
  core_ev_set_allocator(EV_ALLOC);
  /* hook 事件循环错误信息 */
  core_ev_set_syserr_cb(EV_ERROR_CB);
  /* 初始化事件循环对象 */
  core_loop *loop = core_loop_fork(CORE_LOOP);

  int status = 0;

  L = lua_newstate(L_ALLOC, NULL);
  if (!L)
    core_exit();

  init_lua_libs(L, WORKER);

  /* 根据进程运行模式选择不同的启动方式 */
  status = getenv("cfadmin_isWorker") ?
  luaL_loadbufferx(L, worker_boot, strlen(worker_boot), "=[worker.lua]", "t") : luaL_loadfile(L, entry);
  if (status > 1){
    LOG("ERROR", lua_tostring(L, -1));
    lua_close(L);
    core_exit();
  }

  if (getenv("cfadmin_isWorker")) {
    lua_pushstring(L, entry);
  }

  status = CO_RESUME(L, NULL, lua_gettop(L) - 1);
  if (status > 1){
    LOG("ERROR", lua_tostring(L, -1));
    lua_close(L);
    core_exit();
  }

  if (status == LUA_YIELD)
    signal_init();

  return core_start(loop, 0);
}

int core_master_run(pid_t *pids, int* pidcount) {
  /* hook libev 内存分配 */
  core_ev_set_allocator(EV_ALLOC);
  /* hook 事件循环错误信息 */
  core_ev_set_syserr_cb(EV_ERROR_CB);
  /* 初始化事件循环对象 */
  core_loop *loop = core_loop_fork(CORE_LOOP);
  /* 设置pid */
  ev_set_userdata(loop, pids);
  /* 初始化信号 */
  signal_init();

  L = lua_newstate(L_ALLOC, NULL);
  if (!L){
    LOG("ERROR", "New Lua State failed.");
    kill(0, SIGQUIT);
    core_exit();
  }

  /* 加载 Lua 标准库 */
  init_lua_libs(L, MASTER);

  /* 读取文件或默认运行 */
  int status = luaL_loadbufferx(L, master_boot, strlen(master_boot), "=[master.lua]", "t");
  if (status != LUA_OK) {
    lua_close(L);
    kill(0, SIGQUIT);
    core_exit();
  }
  /* 注入子进程Pid */
  lua_createtable(L, 0, 0);
  int index;
  for (index = 0; index < *pidcount; index++) {
    lua_pushinteger(L, pids[index]);
    lua_seti(L, -2, index + 1);
  }
  /* 开始执行 */
  status = CO_RESUME(L, NULL, lua_gettop(L) - 1);
  if (status != LUA_YIELD){
    LOG("ERROR", lua_tostring(L, -1));
    lua_close(L);
    kill(0, SIGQUIT);
    core_exit();
  }
  /* 初始化主进程 */ 
  return core_start(loop, 0);
}
