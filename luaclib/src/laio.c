#define LUA_LIB

#include <core.h>
#include <eio.h>

#define EIO_STACKSIZE (1 << 16)

/* 最小线程数量 */
#define AIO_MAX_NTHREADS 8

#define req_data_to_coroutine(req) (req->data)

#define luaL_push_string_integer(L, k, v) ({ lua_pushliteral(L, k); lua_pushinteger(L, (v)); lua_rawset(L, -3); })
#define luaL_push_string_string(L, k, v) ({ lua_pushliteral(L, k); lua_pushstring(L, (v)); lua_rawset(L, -3); })

 #ifndef S_ISDIR
   #define S_ISDIR(mode)  (mode & _S_IFDIR)
 #endif
 #ifndef S_ISREG
   #define S_ISREG(mode)  (mode & _S_IFREG)
 #endif
 #ifndef S_ISLNK
   #define S_ISLNK(mode)  (0)
 #endif
 #ifndef S_ISSOCK
   #define S_ISSOCK(mode)  (0)
 #endif
 #ifndef S_ISFIFO
   #define S_ISFIFO(mode)  (0)
 #endif
 #ifndef S_ISCHR
   #define S_ISCHR(mode)  (mode&_S_IFCHR)
 #endif
 #ifndef S_ISBLK
   #define S_ISBLK(mode)  (0)
 #endif

static const char *mode2string (mode_t mode) {
  if ( S_ISREG(mode) )
    return "file";
  else if ( S_ISDIR(mode) )
    return "directory";
  else if ( S_ISLNK(mode) )
    return "link";
  else if ( S_ISSOCK(mode) )
  return "socket";
  else if ( S_ISFIFO(mode) )
    return "named pipe";
  else if ( S_ISCHR(mode) )
    return "char device";
  else if ( S_ISBLK(mode) )
    return "block device";
  else
    return "other";
}

static const char *perm2string (mode_t mode) {
  static char perms[10] = "---------";
  int i;
  for (i=0;i<9;i++) perms[i]='-';
  if (mode & S_IRUSR) perms[0] = 'r';
  if (mode & S_IWUSR) perms[1] = 'w';
  if (mode & S_IXUSR) perms[2] = 'x';
  if (mode & S_IRGRP) perms[3] = 'r';
  if (mode & S_IWGRP) perms[4] = 'w';
  if (mode & S_IXGRP) perms[5] = 'x';
  if (mode & S_IROTH) perms[6] = 'r';
  if (mode & S_IWOTH) perms[7] = 'w';
  if (mode & S_IXOTH) perms[8] = 'x';
  return perms;
}

static inline void luaL_push_stat(lua_State *co, eio_req *req) { 
  struct stat *st = (struct stat *)req->ptr2;
  luaL_push_string_string(co,  "mode", mode2string(st->st_mode));
  luaL_push_string_integer(co, "dev", st->st_dev); 
  luaL_push_string_integer(co, "ino", st->st_ino); 
  luaL_push_string_integer(co, "nlink", st->st_nlink); 
  luaL_push_string_integer(co, "uid", st->st_uid); 
  luaL_push_string_integer(co, "gid", st->st_gid); 
  luaL_push_string_integer(co, "rdev", st->st_rdev); 
  luaL_push_string_integer(co, "access", st->st_atime); 
  luaL_push_string_integer(co, "change", st->st_ctime); 
  luaL_push_string_integer(co, "modification", st->st_mtime); 
  luaL_push_string_integer(co, "size", st->st_size); 
  luaL_push_string_integer(co, "blocks", st->st_blocks); 
  luaL_push_string_integer(co, "blksize", st->st_blksize); 
  luaL_push_string_string(co,  "permissions", perm2string(st->st_mode));
}

static int sp[2];

static core_io io_watcher;

// static int myindex = 1;

/* AIO方法只需要简单返回状态时, 可以使用这个回调 */
int AIO_RESPONSE(eio_req* req) {
  lua_State* co = (lua_State*)req_data_to_coroutine(req);
  // printf("当前线程ID为: %d, 协程状态: (%p)%d, index = %d, n = %d\n", pthread_self(), co, lua_status(co), myindex++, eio_npending());  
  if (EIO_RESULT (req)){
    lua_pushboolean(co, 0);
    lua_pushstring(co, strerror(req-> errorno));
  }else{
    lua_pushboolean(co, 1);
  }
  if (LUA_OK != CO_RESUME(co, NULL, lua_gettop(co) - 1)) {
    LOG("ERROR", lua_tostring(co, -1));
  }
  return 0;
}

/* AIO调用stat是需要使用此回调 */
int AIO_RESPONSE_STAT(eio_req* req) {
  lua_State* co = (lua_State*)req_data_to_coroutine(req);
  if (EIO_RESULT (req) != -1){
    lua_createtable(co, 0, 16);
    luaL_push_stat(co, req);
  }
  if (LUA_OK != CO_RESUME(co, NULL, lua_gettop(co) - 1)) {
    LOG("ERROR", lua_tostring(co, -1));
  }
  return 0;
}

/* AIO调用需要循环检查文件名称必须使用此回调 */
int AIO_RESPONSE_DIR(eio_req* req) {
  lua_State* co = (lua_State*)req_data_to_coroutine(req);
  if (EIO_RESULT (req) >= 0){
    lua_createtable(co, EIO_RESULT (req), 0);
    char *buf = (char *)EIO_BUF (req);
    for (int i = 0; i < EIO_RESULT (req); i++) {
      lua_pushlstring(co, buf, strlen(buf));
      lua_rawseti(co, -2, i + 1);
      buf += strlen(buf) + 1;
    }
  }
  if (LUA_OK != CO_RESUME(co, NULL, lua_gettop(co) - 1)) {
    LOG("ERROR", lua_tostring(co, -1));
  }
  return 0;
}

/* AIO调用需要循环检查文件名称必须使用此回调 */
int AIO_RESPONSE_PATH(eio_req* req) {
  lua_State* co = (lua_State*)req_data_to_coroutine(req);
  if (EIO_RESULT (req) >= 0){
    /* 文档中说明:成功后 req->result 为 req->ptr2 指针长度*/
    lua_pushlstring(co, req->ptr2, EIO_RESULT (req));
  }
  if (LUA_OK != CO_RESUME(co, NULL, lua_gettop(co) - 1)) {
    LOG("ERROR", lua_tostring(co, -1));
  }
  return 0;
}

static void AIO_WANT_POLL(void) {
  // printf("AIO_WANT_POLL Called. 主线程ID为: %d\n", pthread_self());
  char event = '1';
  write(sp[1], &event, 1);
 }

static void AIO_DONE_POLL(void) { 
  // printf("AIO_DONE_POLL Called. 主线程ID为: %d\n", pthread_self());
  char event = '2';
  read(sp[0], &event, 1);
}

static void AIO_EVENT(CORE_P_ core_io *io, int revents) {
  if (revents & EV_ERROR) {
    LOG("ERROR", "Recevied a core_io object internal error from libev.");
    return ;
  }
  if (revents & EV_READ){ 
    /* 根据边缘触发规则, 只要还有请求则会不断检查 */
    while (eio_npending() && !eio_poll ());
  }
}

int pip_init() {

  /* 创建管道 */
  if (-1 == socketpair(AF_LOCAL, SOCK_STREAM, 0, sp))
    return -1;

  /* 非阻塞 */
  non_blocking(sp[0]);

  /* 将写socket设置为阻塞操作, 这样能防止问题进一步扩散 */
  non_blocking(sp[1]);

  memset(&io_watcher, 0x0, sizeof(core_io));

  core_io_init(&io_watcher, AIO_EVENT, sp[0], EV_READ);

  core_io_start(CORE_LOOP_ &io_watcher);

  return 0;

}

int aio_init() {

  /* 初始化eio内部数据 */
  if (eio_init(AIO_WANT_POLL, AIO_DONE_POLL))
    return -1;

  /* 创建并初始化通讯管道 */
  if (pip_init())
    return -1;

  /* 设置工作线程数量 */
  eio_set_min_parallel(AIO_MAX_NTHREADS);
  eio_set_max_parallel(AIO_MAX_NTHREADS);
  eio_set_max_idle(AIO_MAX_NTHREADS);

  return 0;

}

static int laio_truncate(lua_State* L) {
  lua_State *t = lua_tothread(L, 1);
  if (!t)
    return luaL_error(L, "Invalid lua coroutine.");

 size_t path_size = 0;
  const char *path = luaL_checklstring(L, 2, &path_size);
  if (!path || path_size < 1){
    return luaL_error(L, "Invalid aio truncate [path].");
  }

  eio_truncate(path, lua_tointeger(L, 3), 0, AIO_RESPONSE, (void*)t);
  return 1;
}

/* aio.realpath 将相对路径转换为绝对路径 */
static int laio_readpath(lua_State* L) {

  lua_State *t = lua_tothread(L, 1);
  if (!t)
    return luaL_error(L, "Invalid lua coroutine.");

  size_t path_size = 0;
  const char *path = luaL_checklstring(L, 2, &path_size);
  if (!path || path_size < 1){
    return luaL_error(L, "Invalid aio readpath [path].");
  }
  eio_realpath (path, 0, AIO_RESPONSE_PATH, (void*)t);
  return 1;
}

/* aio.readdir 读取文件夹内容 */
static int laio_readdir(lua_State* L) {

  lua_State *t = lua_tothread(L, 1);
  if (!t)
    return luaL_error(L, "Invalid lua coroutine.");

  size_t path_size = 0;
  const char *path = luaL_checklstring(L, 2, &path_size);
  if (!path || path_size < 1){
    return luaL_error(L, "Invalid aio readdir [path].");
  }

  eio_readdir (path, EIO_READDIR_DIRS_FIRST, 0, AIO_RESPONSE_DIR, (void*)t);
  return 1;
}

/* aio.rename 重命名文件/文件夹 */
static int laio_rename(lua_State* L) {

  lua_State *t = lua_tothread(L, 1);
  if (!t)
    return luaL_error(L, "Invalid lua coroutine.");

  size_t old_path_size = 0;
  const char *old_path = luaL_checklstring(L, 2, &old_path_size);
  if (!old_path || old_path_size < 1){
    return luaL_error(L, "Invalid aio rename [old path].");
  }

  size_t new_path_size = 0;
  const char *new_path = luaL_checklstring(L, 3, &new_path_size);
  if (!new_path || new_path_size < 1){
    return luaL_error(L, "Invalid aio rename [new path].");
  }

  eio_rename (old_path, new_path, 0, AIO_RESPONSE, (void*)t);
  return 1;
}


/* aio.stat 获取文件/文件夹状态 */
static int laio_stat(lua_State* L) {

  lua_State *t = lua_tothread(L, 1);
  if (!t)
    return luaL_error(L, "Invalid lua coroutine.");

  size_t path_size = 0;
  const char *path = luaL_checklstring(L, 2, &path_size);
  if (!path || path_size < 1){
    return luaL_error(L, "Invalid aio stat [path].");
  }

  eio_stat (path, 0, AIO_RESPONSE_STAT, (void*)t);
  return 1;
}

/* aio.create 创建文件 */
static int laio_create(lua_State* L) {

  lua_State *t = lua_tothread(L, 1);
  if (!t)
    return luaL_error(L, "Invalid lua coroutine.");

  size_t path_size = 0;
  const char *path = luaL_checklstring(L, 2, &path_size);
  if (!path || path_size < 1){
    return luaL_error(L, "Invalid aio create [path].");
  }
  eio_open(path, O_CREAT, 0755, 0, AIO_RESPONSE, (void*)t);
  return 1;
}

/* aio.mkdir 创建文件夹 */
static int laio_mkdir(lua_State* L) {

  lua_State *t = lua_tothread(L, 1);
  if (!t)
    return luaL_error(L, "Invalid lua coroutine.");

  size_t path_size = 0;
  const char *path = luaL_checklstring(L, 2, &path_size);
  if (!path || path_size < 1){
    return luaL_error(L, "Invalid aio mkdir [path].");
  }

  eio_mkdir (path, 0755, 0, AIO_RESPONSE, (void*)t);
  return 1;
}

/* aio.rmdir 删除文件夹 */
static int laio_rmdir(lua_State* L) {

  lua_State *t = lua_tothread(L, 1);
  if (!t)
    return luaL_error(L, "Invalid lua coroutine.");

  size_t path_size = 0;
  const char *path = luaL_checklstring(L, 2, &path_size);
  if (!path || path_size < 1){
    return luaL_error(L, "Invalid aio rmdir [path].");
  }

  eio_rmdir (path, 0, AIO_RESPONSE, (void*)t);
  return 1;
}

LUAMOD_API int luaopen_laio(lua_State* L){
  // printf("主线程ID为: %d\n", pthread_self());
  luaL_checkversion(L);
  if (aio_init()){
    return luaL_error(L, "aio init error.");
  }
  luaL_Reg aio_libs[] = {
    { "mkdir", laio_mkdir },
    { "rmdir", laio_rmdir },
    { "stat", laio_stat },
    { "create", laio_create },
    { "rename", laio_rename },
    { "readdir", laio_readdir },
    { "readpath", laio_readpath },
    { "truncate", laio_truncate },
    {NULL, NULL},
  };
  luaL_newlib(L, aio_libs);
  return 1;
}
