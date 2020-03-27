#define LUA_LIB

/* 工作线程最大使用堆栈 */
#define EIO_STACKSIZE (1 << 16)

#include <core.h>
#include <eio.h>

/* 初始化 */
static int INITIALIZATION = 0;

/* 最小线程数量 */
#define AIO_MAX_NTHREADS (8)

#define req_data_to_coroutine(req) (req->data)

#define luaL_push_string_string(L, k, v) ({ lua_pushliteral(L, k); lua_pushstring(L, (v)); lua_rawset(L, -3); })

/* --- 文件(夹)类型 --- */

/* 内核宏 判断类型是否为目录 */
#ifndef S_ISDIR
 #define S_ISDIR(mode)  (mode & _S_IFDIR)
#endif

/* 内核宏 判断类型是否为常规文件 */
#ifndef S_ISREG
 #define S_ISREG(mode)  (mode & _S_IFREG)
#endif

/* 内核宏 判断是否为链接 */
#ifndef S_ISLNK
 #define S_ISLNK(mode)  (0)
#endif

/* 内核宏 判断是否为域套接字 */
#ifndef S_ISSOCK
 #define S_ISSOCK(mode)  (0)
#endif

/* 内核宏 判断是否为命名管道 */
#ifndef S_ISFIFO
 #define S_ISFIFO(mode)  (0)
#endif

/* 内核宏 判断是否为字符设备 */
#ifndef S_ISCHR
 #define S_ISCHR(mode)  (mode & _S_IFCHR)
#endif

/* 内核宏 判断是否为块设备 */
#ifndef S_ISBLK
 #define S_ISBLK(mode)  (0)
#endif

/* --- 文件(夹)类型 --- */

/* --- 文件(夹)权限 --- */

/* 拥有者是否有读权限 */
#ifndef S_IRUSR
 #define S_IRUSR (1 << 8)
#endif

/* 拥有者是否有写权限 */
#ifndef S_IWUSR
 #define S_IWUSR (1 << 7)
#endif

/* 拥有者是否有执行权限 */
#ifndef S_IXUSR
 #define S_IXUSR (1 << 6)
#endif

/* 用户组是否有读权限 */
#ifndef S_IRGRP
 #define S_IRGRP (1 << 5)
#endif

/* 用户组是否有写权限 */
#ifndef S_IWGRP
 #define S_IWGRP (1 << 4)
#endif

/* 用户组是否有执行权限 */
#ifndef S_IXGRP
 #define S_IXGRP (1 << 3)
#endif

/* 其他人是否有读权限 */
#ifndef S_IROTH
 #define S_IROTH (1 << 2)
#endif

/* 其他人是否有写权限 */
#ifndef S_IWOTH
 #define S_IWOTH (1 << 1)
#endif

/* 其他人是否有执行权限 */
#ifndef S_IXOTH
 #define S_IXOTH (1 << 0)
#endif

/* --- 文件(夹)权限 --- */

static inline void luaL_push_string_integer(lua_State* L, const char* k, int v) {
  lua_pushstring(L, k);
  lua_pushinteger(L, v);
  lua_rawset(L, -3);
}

/* 文件类型转字符串 */
static inline const char *mode2string (mode_t mode) {
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

/* 权限转字符串 */
static inline const char *perm2string (mode_t mode, char* perms) {
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
  char permissions[10] = "---------";
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
  luaL_push_string_string(co,  "permissions", perm2string(st->st_mode, permissions));
}

/* AIO方法只需要简单返回状态时, 可以使用这个回调 */
static int AIO_RESPONSE(eio_req* req) {
  lua_State* co = (lua_State*)req_data_to_coroutine(req);
  if (EIO_RESULT (req)){
    lua_pushboolean(co, 0);
    lua_pushstring(co, strerror(req->errorno));
  }else{
    lua_pushboolean(co, 1);
  }
  if (LUA_OK != CO_RESUME(co, NULL, lua_gettop(co) - 1)) {
    LOG("ERROR", lua_tostring(co, -1));
  }
  return 0;
}

/* AIO方法需要返回数值和fd时, 可以使用这个回调 */
static int AIO_RESPONSE_FD(eio_req* req) {
  lua_State* co = (lua_State*)req_data_to_coroutine(req);
  if (EIO_RESULT (req) == -1){
    lua_pushboolean(co, 0);
    lua_pushstring(co, strerror(req->errorno));
  }else{
    lua_pushinteger(co, EIO_RESULT (req));
  }
  if (LUA_OK != CO_RESUME(co, NULL, lua_gettop(co) - 1)) {
    LOG("ERROR", lua_tostring(co, -1));
  }
  return 0;
}

/* AIO调用读取数据则需要使用此回调 */
static int AIO_RESPONSE_READ(eio_req* req) {
  lua_State* co = (lua_State*)req_data_to_coroutine(req);
  if (EIO_RESULT (req) == -1){
    lua_pushboolean(co, 0);
    lua_pushstring(co, strerror(req->errorno));
  }else{
    lua_pushlstring(co, EIO_BUF (req), EIO_RESULT (req));
    lua_pushinteger(co, EIO_RESULT (req));
  }
  if (LUA_OK != CO_RESUME(co, NULL, lua_gettop(co) - 1)) {
    LOG("ERROR", lua_tostring(co, -1));
  }
  return 0;
}

/* AIO调用写入数据则需要使用此回调 */
static int AIO_RESPONSE_WRITE(eio_req* req) {
  lua_State* co = (lua_State*)req_data_to_coroutine(req);
  if (EIO_RESULT (req) == -1){
    lua_pushboolean(co, 0);
    lua_pushstring(co, strerror(req->errorno));
  }else{
    lua_pushinteger(co, EIO_RESULT (req));
  }
  if (LUA_OK != CO_RESUME(co, NULL, lua_gettop(co) - 1)) {
    LOG("ERROR", lua_tostring(co, -1));
  }
  return 0;
}

/* AIO调用stat是需要使用此回调 */
static int AIO_RESPONSE_STAT(eio_req* req) {
  lua_State* co = (lua_State*)req_data_to_coroutine(req);
  if (EIO_RESULT (req) != -1){
    lua_createtable(co, 0, 16);
    luaL_push_stat(co, req);
  }else{
    lua_pushboolean(co, 0);
    lua_pushstring(co, strerror(req->errorno));
  }
  if (LUA_OK != CO_RESUME(co, NULL, lua_gettop(co) - 1)) {
    LOG("ERROR", lua_tostring(co, -1));
  }
  return 0;
}

/* AIO调用需要循环检查文件名称必须使用此回调 */
static int AIO_RESPONSE_DIR(eio_req* req) {
  lua_State* co = (lua_State*)req_data_to_coroutine(req);
  if (EIO_RESULT (req) >= 0){
    lua_createtable(co, EIO_RESULT (req), 0);
    char *buf = (char *)EIO_BUF (req);
    int i;
    for (i = 0; i < EIO_RESULT (req); i++) {
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

typedef struct aio_file{
  FILE *f;
  lua_State *L;
}aio_file;

static int AIO_RESPONSE_FFLUSH(eio_req* req) {
  aio_file* afile = (aio_file*)req_data_to_coroutine(req);
  if (EIO_RESULT (req) == -1){
    lua_pushboolean(afile->L, 0);
    lua_pushstring(afile->L, strerror(req->errorno));
  }else {
    lua_pushboolean(afile->L, 1);
  }
  if (LUA_OK != CO_RESUME(afile->L, NULL, lua_gettop(afile->L) - 1)) {
    LOG("ERROR", lua_tostring(afile->L, -1));
  }
  return 0;
}

static void AIO_FFLUSH(eio_req *req) {
  aio_file* afile = (aio_file*)req->data;
  if ((req->result = fflush(afile->f)) == -1) {
    req->errorno = errno;
  }
}

static int sp[2];

static void AIO_WANT_POLL(void) {
  // printf("AIO_WANT_POLL Called. 工作线程ID为: %d\n", pthread_self());
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

static core_io io_watcher;

static int pip_init() {

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

static int aio_init() {

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



/* aio.open 打开一个文件(不存在则创建) */
static int laio_open(lua_State* L) {
  lua_State *t = lua_tothread(L, 1);
  if (!t)
    return luaL_error(L, "Invalid lua coroutine.");

  size_t path_size = 0;
  const char *path = luaL_checklstring(L, 2, &path_size);
  if (!path || path_size < 1){
    return luaL_error(L, "Invalid aio open [path].");
  }

  eio_open(path, O_CREAT | O_RDWR, 0755, EIO_PRI_DEFAULT, AIO_RESPONSE_FD, (void*)t);

  return 1;
}

/* aio.create 创建一个文件(存在则返回错误) */
static int laio_create(lua_State* L) {
  lua_State *t = lua_tothread(L, 1);
  if (!t)
    return luaL_error(L, "Invalid lua coroutine.");

  size_t path_size = 0;
  const char *path = luaL_checklstring(L, 2, &path_size);
  if (!path || path_size < 1){
    return luaL_error(L, "Invalid aio create [path].");
  }

  eio_open(path, O_RDWR | O_CREAT | O_EXCL, 0755, EIO_PRI_DEFAULT, AIO_RESPONSE_FD, (void*)t);

  return 1;
}

/* aio.read 从文件内读取数据  */
static int laio_read(lua_State* L) {
  lua_State *t = lua_tothread(L, 1);
  if (!t)
    return luaL_error(L, "Invalid lua coroutine.");

  /* 当offset大于0使用pread, 否则使用read */
  eio_read(lua_tointeger(L, 2), 0, lua_tointeger(L, 3),lua_tointeger(L, 4), EIO_PRI_DEFAULT, AIO_RESPONSE_READ, (void*)t);
  return 1;
}

/* aio.write 写入数据到文件内  */
static int laio_write(lua_State* L) {
  lua_State *t = lua_tothread(L, 1);
  if (!t)
    return luaL_error(L, "Invalid lua coroutine.");

  int fd = lua_tointeger(L, 2);

  size_t buffer_size = 0;
  const char *buffer = luaL_checklstring(L, 3, &buffer_size);
  if (!buffer || buffer_size < 1){
    return luaL_error(L, "Invalid aio write [buffer].");
  }

  /* 当offset大于等于0使用pwrite, 否则使用write */
  eio_write(fd, (void*)buffer, buffer_size, lua_tointeger(L, 4), EIO_PRI_DEFAULT, AIO_RESPONSE_WRITE, (void*)t);
  return 1;
}

/* aio.flush 将文件内存数据刷新到磁盘 */
static int laio_flush(lua_State* L) {
  lua_State *t = lua_tothread(L, 1);
  if (!t)
    return luaL_error(L, "Invalid lua coroutine.");

  eio_fsync(lua_tointeger(L, 2), EIO_PRI_DEFAULT, AIO_RESPONSE, (void*)t);

  return 1;
}

/* aio.fflush 将文件内存数据刷新到磁盘 */
static int laio_fflush(lua_State* L) {

  aio_file* afile = lua_newuserdata(L, sizeof(aio_file));

  afile->L = lua_tothread(L, 1);
  if (!afile->L)
    return luaL_error(L, "Invalid lua coroutine.");

  luaL_Stream *p = luaL_checkudata(L, 2, LUA_FILEHANDLE);
  if (!p || !p->closef)
    luaL_error(L, "attempt to use a closed file");

  afile->f = p->f;

  eio_custom(AIO_FFLUSH, 0, AIO_RESPONSE_FFLUSH, afile);

  return 1;
}

/* aio.close 关闭文件描述符  */
static int laio_close(lua_State* L) {
  lua_State *t = lua_tothread(L, 1);
  if (!t)
    return luaL_error(L, "Invalid lua coroutine.");

  eio_close(lua_tointeger(L, 2), EIO_PRI_DEFAULT, AIO_RESPONSE, (void*)t);

  return 1;
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

  eio_truncate(path, lua_tointeger(L, 3), EIO_PRI_DEFAULT, AIO_RESPONSE, (void*)t);
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
  eio_realpath (path, EIO_PRI_DEFAULT, AIO_RESPONSE_PATH, (void*)t);
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

  eio_readdir (path, EIO_READDIR_DIRS_FIRST, EIO_PRI_DEFAULT, AIO_RESPONSE_DIR, (void*)t);
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

  eio_rename (old_path, new_path, EIO_PRI_DEFAULT, AIO_RESPONSE, (void*)t);
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

  eio_stat (path, EIO_PRI_DEFAULT, AIO_RESPONSE_STAT, (void*)t);
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

  eio_mkdir (path, 0755, EIO_PRI_DEFAULT, AIO_RESPONSE, (void*)t);
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

  eio_rmdir (path, EIO_PRI_DEFAULT, AIO_RESPONSE, (void*)t);
  return 1;
}

LUAMOD_API int luaopen_laio(lua_State* L){
  // printf("主线程ID为: %d\n", pthread_self());
  luaL_checkversion(L);
  if (!INITIALIZATION){
    if (aio_init()){
      return luaL_error(L, "aio init error.");
    }
    INITIALIZATION = 1;
  }
  luaL_Reg aio_libs[] = {
    { "mkdir", laio_mkdir },
    { "rmdir", laio_rmdir },
    { "stat", laio_stat },
    { "rename", laio_rename },
    { "readdir", laio_readdir },
    { "readpath", laio_readpath },
    { "truncate", laio_truncate },
    { "open", laio_open },
    { "read", laio_read },
    { "write", laio_write },
    { "flush", laio_flush },
    { "close", laio_close },
    { "create", laio_create },
    { "fflush", laio_fflush },
    {NULL, NULL},
  };
  luaL_newlib(L, aio_libs);
  return 1;
}
