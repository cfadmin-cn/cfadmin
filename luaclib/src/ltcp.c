#define LUA_LIB

#include <core.h>
#include <openssl/ssl.h>
#include <openssl/err.h>
#include <openssl/crypto.h>

#define None (-1)
#define SERVER (0)
#define CLIENT (1)

static inline void SETSOCKETOPT(int sockfd, int mode){
  int Enable = 1;
  int ret = 0;
  /* 设置非阻塞 */
  non_blocking(sockfd);
/* 地址重用 */
#ifdef SO_REUSEADDR
  ret = setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &Enable, sizeof(Enable));
  if (ret < 0) {
    LOG("ERROR", "Setting SO_REUSEADDR failed.");
    LOG("ERROR", strerror(errno));
    return core_exit();
  }
#endif

/* 端口重用 */
#ifdef SO_REUSEPORT
  if (mode == SERVER) {
  #ifdef SO_REUSEPORT_LB
    // BSD系统的多进程负载需要使用此宏
    ret = setsockopt(sockfd, SOL_SOCKET, SO_REUSEPORT_LB, &Enable, sizeof(Enable));
  #else
    ret = setsockopt(sockfd, SOL_SOCKET, SO_REUSEPORT, &Enable, sizeof(Enable));
  #endif
    if (ret < 0) {
      LOG("ERROR", "Setting SO_REUSEPORT failed.");
      LOG("ERROR", strerror(errno));
      return core_exit();
    }
  }
#endif

/* 关闭连接不会阻塞 */
#ifdef SO_LINGER
  struct linger lin = { .l_onoff = 0, .l_linger = 0 };
  ret = setsockopt(sockfd, SOL_SOCKET, SO_LINGER, &lin , sizeof(lin));
  if (ret < 0){
    LOG("ERROR", "Setting SO_LINGER failed.");
    LOG("ERROR", strerror(errno));
    return core_exit();
  }
#endif

/* 开启 TCP keepalive */
#ifdef SO_KEEPALIVE
  if (mode != None){
    ret = setsockopt(sockfd, SOL_SOCKET, SO_KEEPALIVE, &Enable , sizeof(Enable));
    if (ret < 0){
      LOG("ERROR", "Setting SO_KEEPALIVE failed.");
      LOG("ERROR", strerror(errno));
      return core_exit();
    }
  }
#endif

/* 关闭小包延迟合并算法 */
#ifdef TCP_NODELAY
  ret = setsockopt(sockfd, IPPROTO_TCP, TCP_NODELAY, &Enable, sizeof(Enable));
  if (ret < 0){
    LOG("ERROR", "Setting TCP_NODELAY failed.");
    LOG("ERROR", strerror(errno));
    return core_exit();
  }
#endif

/* 开启延迟Accept, 没数据来之前不回调accept */
#if defined(TCP_DEFER_ACCEPT)
  if (mode == SERVER) {
    ret = setsockopt(sockfd, IPPROTO_TCP, TCP_DEFER_ACCEPT, &Enable, sizeof(Enable));
    if (ret < 0){
      LOG("WARN", "Setting TCP_DEFER_ACCEPT failed.");
      LOG("WARN", strerror(errno));
      // 不能退出的原因是因为要兼容那垃圾WSL实现.
      // return core_exit();
    }
  }
#elif defined(SO_ACCEPTFILTER)
  /* TODO: 暂不实现 */
#endif

/* 开启TCP快速连接 */
#if defined(TCP_FASTOPEN) && defined(MSG_FASTOPEN)
  if (mode == SERVER) {
    int len = 5;
    ret = setsockopt(sockfd, IPPROTO_TCP, TCP_FASTOPEN, &len, sizeof(len));
    if (ret < 0){
      LOG("WARN", "Setting TCP_FASTOPEN failed.");
      LOG("WARN", strerror(errno));
      // 不能退出的原因是因为要兼容那垃圾WSL实现.
      // return core_exit();
    }
  }
#endif

/* 设置 TCP keepalive 空闲时间 */
#ifdef TCP_KEEPIDLE
  int keepidle = 30;
  ret = setsockopt(sockfd, IPPROTO_TCP, TCP_KEEPIDLE, &keepidle , sizeof(keepidle));
  if (ret < 0){
    LOG("ERROR", "Setting TCP_KEEPIDLE failed.");
    LOG("ERROR", strerror(errno));
    return core_exit();
  }
#endif

/* 设置 TCP keepalive 探测总次数 */
#ifdef TCP_KEEPCNT
  int keepcount = 3;
  ret = setsockopt(sockfd, IPPROTO_TCP, TCP_KEEPCNT, &keepcount , sizeof(keepcount));
  if (ret < 0){
    LOG("ERROR", "Setting TCP_KEEPCNT failed.");
    LOG("ERROR", strerror(errno));
    return core_exit();
  }
#endif

/* 设置 TCP keepalive 每次探测间隔时间 */
#ifdef TCP_KEEPINTVL
  int keepinterval = 5;
  ret = setsockopt(sockfd, IPPROTO_TCP, TCP_KEEPINTVL, &keepinterval , sizeof(keepinterval));
  if (ret < 0){
    LOG("ERROR", "Setting TCP_KEEPINTVL failed.");
    LOG("ERROR", strerror(errno));
    return core_exit();
  }
#endif

/* 开启IPV6与ipv4双栈 */
#ifdef IPV6_V6ONLY
  if (mode != None) {
    int No = 0;
    ret = setsockopt(sockfd, IPPROTO_IPV6, IPV6_V6ONLY, (void *)&No, sizeof(No));
    if (ret < 0){
      LOG("ERROR", "Setting IPV6_V6ONLY failed.");
      LOG("ERROR", strerror(errno));
      return core_exit();
    }
  }
#endif

}

/* server fd */
static int create_server_fd(const char *ip, int port, int backlog){
  errno = 0;
  /* 建立 TCP Server Socket */
  int sockfd = socket(AF_INET6, SOCK_STREAM, IPPROTO_TCP);
  if (0 >= sockfd){
    LOG("ERROR", strerror(errno));
    return -1;
  }
  /* socket option set */
  SETSOCKETOPT(sockfd, SERVER);

  struct sockaddr_in6 SA;
  memset(&SA, 0x0, sizeof(SA));

  SA.sin6_family = AF_INET6;
  SA.sin6_port = htons(port);
  SA.sin6_addr = in6addr_any;

  struct in6_addr addr;
  /* 如果填写的是`::1` */
  if (!strcmp(ip, "::1") && inet_pton(AF_INET6, "::1", &addr) == 1){
    SA.sin6_addr = addr;
  /* 如果填写的是`127.0.0.1` */
  } else if (!strcmp(ip, "127.0.0.1") && inet_pton(AF_INET6, "::ffff:127.0.0.1", &addr) == 1) {
    SA.sin6_addr = addr;
  /* 如果填写的是其它`IPv6`地址 */
  } else if (inet_pton(AF_INET6, ip, &addr) == 1) {
    SA.sin6_addr = addr;
  /* 如果填写的是 `0.0.0.0` 则监听所有地址 */
  } else if (!strcmp(ip, "0.0.0.0")) {
    SA.sin6_addr = in6addr_any;
  /* 检查IPv4地址或者是非法IP地址 */
  } else {
    struct in_addr addr4;
    if (inet_pton(AF_INET, ip, &addr4) == 1) {
      char *ipv6 = alloca(strlen(ip) + 8);
      memset(ipv6, 0x0, strlen(ip) + 8);
      memmove(ipv6, "::ffff:", 7);
      memmove(ipv6 + 7, ip, strlen(ip));
      if (inet_pton(AF_INET6, ipv6, &addr) != 1){
        close(sockfd);
        return -1;
      }
      SA.sin6_addr = addr;
    }
  }

  /* 绑定套接字失败 */
  int bind_success = bind(sockfd, (struct sockaddr *)&SA, sizeof(SA));
  if (0 > bind_success) {
    close(sockfd);
    return -1;
  }

  /* 监听套接字失败 */
  int listen_success = listen(sockfd, backlog);
  if (0 > listen_success) {
    close(sockfd);
    return -1;
  }

  return sockfd;
}

/* client fd */
static int create_client_fd(const char *ipaddr, int port){
  errno = 0;
  /* 建立 TCP Client Socket */
  int sockfd = socket(AF_INET6, SOCK_STREAM, IPPROTO_TCP);
  if (0 >= sockfd) {
    LOG("ERROR", strerror(errno));
    return -1;
  }

  /* socket option set */
  SETSOCKETOPT(sockfd, CLIENT);

  struct sockaddr_in6 SA;
  memset(&SA, 0x0, sizeof(SA));

  SA.sin6_family = AF_INET6;
  SA.sin6_port = htons(port);
  int error = inet_pton(AF_INET6, ipaddr, &SA.sin6_addr);
  if (1 != error) {
    LOG("ERROR", strerror(errno));
    close(sockfd);
    return -1;
  }

  int ret = connect(sockfd, (struct sockaddr*)&SA, sizeof(SA));
  if (ret < 0 && errno != EINPROGRESS){
    LOG("ERROR", strerror(errno));
    close(sockfd);
    return -1;
  }
  return sockfd;
}

static int create_server_unixsock(const char* path, size_t path_len, int backlog) {
  errno = 0;
  int sockfd = socket(AF_LOCAL, SOCK_STREAM, IPPROTO_IP);
  if (0 >= sockfd){
    LOG("ERROR", strerror(errno));
    return -1;
  }

  struct sockaddr_un UN;
  memset(&UN, 0x0, sizeof(UN));

  UN.sun_family = AF_LOCAL;
  memmove(UN.sun_path, path, path_len);

  non_blocking(sockfd);

  /* 绑定套接字失败 */
  int bind_success = bind(sockfd, (struct sockaddr *)&UN, sizeof(UN));
  if (0 > bind_success) {
    LOG("ERROR", strerror(errno));
    close(sockfd);
    return -1;
  }

  /* 监听套接字失败 */
  int listen_success = listen(sockfd, backlog);
  if (0 > listen_success) {
    LOG("ERROR", strerror(errno));
    close(sockfd);
    return -1;
  }

  return sockfd;
}

static void TCP_IO_CB(CORE_P_ core_io *io, int revents) {
  if (revents & EV_ERROR) {
    LOG("ERROR", "Recevied a core_io object internal error from libev.");
    return ;
  }
  lua_State *co = (lua_State *)core_get_watcher_userdata(io);
  if (lua_status(co) == LUA_YIELD || lua_status(co) == LUA_OK){
    int status = CO_RESUME(co, NULL, 0);
    if (status != LUA_YIELD && status != LUA_OK){
      LOG("ERROR", lua_tostring(co, -1));
      core_io_stop(CORE_LOOP_ io);
    }
  }
}

static void IO_CONNECT(CORE_P_ core_io *io, int revents){
  if (revents & EV_ERROR) {
    LOG("ERROR", "Recevied a core_io object internal error from libev.");
    return ;
  }
  if (revents & EV_WRITE){
    lua_State *co = (lua_State *)core_get_watcher_userdata(io);
    if (lua_status(co) == LUA_YIELD || lua_status(co) == LUA_OK){
      socklen_t len = sizeof(socklen_t); int err = 0; int connected = 0;
      if(getsockopt(io->fd, SOL_SOCKET, SO_ERROR, &err, (socklen_t*)&len) == 0 && err == 0) connected = 1;
      lua_pushboolean(co, connected);
      if (err) lua_pushstring(co, strerror(err));
      int status = CO_RESUME(co, NULL, lua_gettop(co) - 1);
      if (status != LUA_YIELD && status != LUA_OK){
        LOG("ERROR", lua_tostring(co, -1));
        core_io_stop(CORE_LOOP_ io);
      }
    }
  }
}

/* 接受链接 */
static void IO_ACCEPT(CORE_P_ core_io *io, int revents){
  if (revents & EV_READ){
    lua_State *co = (lua_State *) core_get_watcher_userdata(io);
    int status = lua_status(co);
    if (status != LUA_YIELD && status != LUA_OK) {
      LOG("ERROR", "accept get a invalid lua vm.");
      return;
    }
    for(;;) {
      errno = 0;
      struct sockaddr_in6 SA;
      socklen_t slen = sizeof(SA);
      memset(&SA, 0x0, slen);
      int client = accept(io->fd, (struct sockaddr*)&SA, &slen);
      if (0 >= client) {
        if (errno != EWOULDBLOCK)
          LOG("ERROR", strerror(errno));
        return;
      }
      SETSOCKETOPT(client, None);
      char buf[INET6_ADDRSTRLEN];
      inet_ntop(AF_INET6, &SA.sin6_addr, buf, INET6_ADDRSTRLEN);
      lua_pushinteger(co, client);
      lua_pushlstring(co, buf, strlen(buf));
      lua_pushinteger(co, SA.sin6_port);
      status = CO_RESUME(co, NULL, status == LUA_YIELD ? lua_gettop(co) : lua_gettop(co) - 1);
      if (status != LUA_YIELD && status != LUA_OK) {
        LOG("ERROR", lua_tostring(co, -1));
        LOG("ERROR", "Error Lua Accept Method");
        core_io_stop(CORE_LOOP_ io);
      }
    }
  }
}

static void IO_ACCEPT_EX(CORE_P_ core_io *io, int revents) {
  if (revents & EV_READ){
    lua_State *co = (lua_State *) core_get_watcher_userdata(io);
    int status = lua_status(co);
    if (status != LUA_YIELD && status != LUA_OK) {
      LOG("ERROR", "accept_ex get a invalid lua vm.");
      return ;
    }
    for (;;) {
      errno = 0;
      struct sockaddr_un UN;
      socklen_t slen = sizeof(UN);
      memset(&UN, 0x0, slen);
      int client = accept(io->fd, (struct sockaddr *)&UN, &slen);
      if (0 >= client) {
        if (errno != EWOULDBLOCK)
          LOG("INFO", strerror(errno));
        return ;
      }
      non_blocking(client);
      lua_pushinteger(co, client);
      // lua_pushlstring(co, UN.sun_path, strlen(UN.sun_path)); // unix domain path
      status = CO_RESUME(co, NULL, status == LUA_YIELD ? lua_gettop(co) : lua_gettop(co) - 1);
      if (status != LUA_YIELD && status != LUA_OK) {
        LOG("ERROR", lua_tostring(co, -1));
        LOG("ERROR", "Error Lua Accept Method");
        core_io_stop(CORE_LOOP_ io);
      }
    }
  }
}

struct io_sendfile {
  int32_t fd;
  off_t pos;
  off_t offset;
  lua_State *L;
};

static void
IO_SENDFILE(CORE_P_ core_io *io, int revents){
  if (revents & EV_WRITE){
    errno = 0;
    struct io_sendfile *sf = core_get_watcher_userdata(io);
#if defined(__APPLE__) || defined(__FreeBSD__)
    int tag = 0; off_t nBytes = 0;
    for (;;) {
    #if defined(__APPLE__)
      tag = sendfile(sf->fd, io->fd, sf->pos, &nBytes, NULL, 0);
    #else
      tag = sendfile(sf->fd, io->fd, sf->pos, 0, NULL, &nBytes, SF_NODISKIO | SF_NOCACHE);
    #endif
      sf->pos += nBytes;
      if (0 > tag) {
        if (errno == EINTR) continue;
        if (errno == EWOULDBLOCK) return;
        lua_pushboolean(sf->L, 0);
        break;
      }
      // 当nBytes与tag同时为0时说明发送成功, 其它情况下都当做发送失败.
      if (0 == nBytes){ lua_pushboolean(sf->L, 1); break; }
    }
#elif defined(linux) || defined(__linux__)
    #include <sys/sendfile.h>
    for (;;) {
      int tag = sendfile(io->fd, sf->fd, NULL, sf->offset);
      if (0 >= tag) {
        if (!tag){ lua_pushboolean(sf->L, 1); break; }
        if (errno == EINTR) continue;
        if (errno == EWOULDBLOCK) return;
        lua_pushboolean(sf->L, 0);
        break;
      }
    }
#else
    char buf[sf->offset];
    for(;;) {
      int rBytes = pread(sf->fd, buf, sf->offset, sf->pos);
      if (rBytes == 0) { lua_pushboolean(sf->L, 1); break; } // 所有数据写入发送完毕.
      int wBytes = write(io->fd, buf, rBytes);
      if (wBytes <= 0) {
        if (errno == EINTR) continue;
        if (errno == EWOULDBLOCK) return;
        lua_pushboolean(sf->L, 0);
        break;
      }
      sf->pos += wBytes;
    }
#endif
    core_set_watcher_userdata(io, NULL);
    int status = CO_RESUME(sf->L, NULL, lua_status(sf->L) == LUA_YIELD ? lua_gettop(sf->L) : lua_gettop(sf->L) - 1);
    if (status != LUA_YIELD && status != LUA_OK) {
      LOG("ERROR", lua_tostring(sf->L, -1));
      LOG("ERROR", "Error Lua SENDFILE Method");
    }
    close(sf->fd);
    xfree(sf);
  }
}

static int tcp_sendfile(lua_State *L){
  core_io *io = (core_io *) luaL_testudata(L, 1, "__TCP__");
  int fd = open(luaL_checkstring(L, 3), O_RDONLY);
  if (fd < 0)
    return luaL_error(L, "[%s]: %s.", luaL_checkstring(L, 3), strerror(errno));

  struct io_sendfile *sf = xmalloc(sizeof(struct io_sendfile));
  sf->L = lua_tothread(L, 2);
  sf->fd = fd;
  sf->offset = luaL_checkinteger(L, 5);
  sf->pos = 0;

  core_set_watcher_userdata(io, sf);
  core_io_init(io, IO_SENDFILE, luaL_checkinteger(L, 4), EV_WRITE);
  core_io_start(CORE_LOOP_ io);
  return 1;
}

static int tcp_peek(lua_State *L) {
  errno = 0;

  int fd = lua_tointeger(L, 1);
  if (0 >= fd) return 0;

  int bsize = lua_tointeger(L, 2);
  char buffer[bsize];

  if (0 == lua_toboolean(L, 3)) {
    lua_pushinteger(L, read(fd, buffer, bsize));
    return 1;
  }

  while (1){
    int len = recv(fd, buffer, bsize, MSG_PEEK);
    if (len <= 0){
      if (errno == EINTR) continue;
      if (errno == EWOULDBLOCK) {
        lua_pushnil(L);
        lua_pushinteger(L, 0);
        break;
      }
      lua_pushnil(L);
      lua_pushstring(L, strerror(errno));
      break;
    }
    lua_pushlstring(L, buffer, bsize);
    lua_pushinteger(L, bsize);
    break;
  }
  return 2;
}

static int tcp_sslpeek(lua_State *L) {
  errno = 0;

  SSL *ssl = lua_touserdata(L, 1);
  if (!ssl) return 0;

  int bsize = lua_tointeger(L, 2);
  char buffer[bsize];

  if (0 == lua_toboolean(L, 3)) {
    lua_pushinteger(L, SSL_read(ssl, buffer, bsize));
    return 1;
  }

  while (1){
    int len = SSL_peek(ssl, buffer, bsize);
    if (len <= 0){
      if (errno == EINTR)
        continue;
      if (SSL_ERROR_WANT_READ == SSL_get_error(ssl, len)){
        lua_pushnil(L);
        lua_pushinteger(L, 0);
        break;
      }
      lua_pushnil(L);
      lua_pushstring(L, strerror(errno));
      break;
    }
    lua_pushlstring(L, buffer, bsize);
    lua_pushinteger(L, bsize);
    break;
  }
  return 2;
}

static int tcp_read(lua_State *L){
  int fd = lua_tointeger(L, 1);
  if (0 >= fd)
    return 0;

  lua_Integer bytes = lua_tointeger(L, 2);
  if (0 >= bytes)
    return 0;

  errno = 0;
  char* str = alloca(1 << 16);
  if (bytes > (1 << 16)){
    str = (char*)lua_newuserdata(L, bytes);
  }
  do {
    int rsize = read(fd, str, bytes);
    if (rsize > 0) {
      lua_pushlstring(L, str, rsize);
      lua_pushinteger(L, rsize);
      return 2;
    }
    if (0 > rsize) {
      if (errno == EINTR) continue;
      if (errno == EWOULDBLOCK) {
        lua_pushnil(L);
        lua_pushinteger(L, 0);
        return 2;
      }
    }
  } while(0);
  lua_pushnil(L);
  lua_pushstring(L, strerror(errno));
  return 2;
}

static int tcp_sslread(lua_State *L){
  SSL *ssl = lua_touserdata(L, 1);
  if (!ssl)
    return 0;

  lua_Integer bytes = lua_tointeger(L, 2);
  if (0 >= bytes)
    return 0;

  char* str = alloca(1 << 16);
  if (bytes > (1 << 16)){
    str = (char*)lua_newuserdata(L, bytes);
  }

  errno = 0;
  do {
    int rsize = SSL_read(ssl, str, bytes);
    if (0 < rsize) {
      lua_pushlstring(L, str, rsize);
      lua_pushinteger(L, rsize);
      return 2;
    }
    if (0 > rsize){
      if (errno == EINTR) continue;
      if (SSL_ERROR_WANT_READ == SSL_get_error(ssl, rsize)){
        lua_pushnil(L);
        lua_pushinteger(L, 0);
        return 2;
      }
    }
  } while (0);
  return 0;
}

static int tcp_write(lua_State *L){
  size_t resp_len = 0;
  int fd = lua_tointeger(L, 1);
  const char *response = luaL_checklstring(L, 2, &resp_len);
  if (!response)
    return luaL_error(L, "tcp_write ERROR: attempt to write an empty string.");

  errno = 0;
  int offset = lua_tointeger(L, 3);
  do {

   int wsize = write(fd, response + offset, resp_len - offset);

   if (wsize > 0) { lua_pushinteger(L, wsize); return 1; }

   if (wsize < 0){
     if (errno == EINTR) continue;
     if (errno == EWOULDBLOCK){ lua_pushinteger(L, 0); return 1;}
   }

  } while (0);

  return 0;
}

static int tcp_sslwrite(lua_State *L){
  SSL *ssl = lua_touserdata(L, 1);
  if (!ssl)
    return 0;

  const char *response = lua_tostring(L, 2);
  if (!response)
    return luaL_error(L, "tcp_sslwrite ERROR: attempt to write an empty string.");

  errno = 0;
  int resp_len = lua_tointeger(L, 3);
  do {
    int wsize = SSL_write(ssl, response, resp_len);
    if (wsize > 0) { lua_pushinteger(L, wsize); return 1; }
    if (wsize < 0){
      if (errno == EINTR) continue;
      if (SSL_ERROR_WANT_WRITE == SSL_get_error(ssl, wsize)){ lua_pushinteger(L, 0); return 1; }
    }
  } while (0);

  return 0;
}

static int new_server_fd(lua_State *L){
  const char *ip = lua_tostring(L, 1);
  if (!ip)
    return 0;

  int port = lua_tointeger(L, 2);
  if (!port)
    return 0;

  int backlog = lua_tointeger(L, 3);

  int fd = create_server_fd(ip, port, 0 >= backlog ? 128 : backlog);
  if (0 >= fd)
    return 0;

  lua_pushinteger(L, fd);
  return 1;
}

static int new_client_fd(lua_State *L){
  const char *ip = lua_tostring(L, 1);
  if (!ip)
    return 0;

  int port = lua_tointeger(L, 2);
  if (!port)
    return 0;

  int fd = create_client_fd(ip, port);
  if (0 >= fd)
    return 0;

  lua_pushinteger(L, fd);
  return 1;
}

static int new_unixsock_fd(lua_State *L) {
  size_t size = 0;
  const char* path = luaL_checklstring(L, 1, &size);
  if (!path)
    return 0;

  /* 传递rm为非nil与false值, 删除已经存在的文件 */
  int rm = lua_toboolean(L, 2);

  /* 文件存在或无法删除的情况下都将创建unixsock失败 */
  if (!access(path, F_OK)) {
    if (!rm || unlink(path))
      return 0;
  }

  int backlog = luaL_checkinteger(L, 3);

  int fd = create_server_unixsock(path, size, 0 >= backlog ? 128 : backlog);
  if (fd <= 0)
    return 0;

  lua_pushinteger(L, fd);
  return 1;
}

static int tcp_listen(lua_State *L){
  core_io *io = (core_io *) luaL_testudata(L, 1, "__TCP__");
  if (!io)
    return 0;

  /* socket文件描述符 */
  int fd = lua_tointeger(L, 2);
  if (0 >= fd)
    return 0;

  /* 回调协程 */
  lua_State *co = lua_tothread(L, 3);
  if (!co)
    return 0;

  core_set_watcher_userdata(io, co);
  core_io_init(io, IO_ACCEPT, fd, EV_READ);
  core_io_start(CORE_LOOP_ io);
  return 1;
}

static int tcp_listen_ex(lua_State *L) {
  core_io *io = (core_io *) luaL_testudata(L, 1, "__TCP__");
  if (!io)
    return 0;

  /* socket文件描述符 */
  int fd = lua_tointeger(L, 2);
  if (0 >= fd)
    return 0;
  /* 回调协程 */
  lua_State *co = lua_tothread(L, 3);
  if (!co)
    return 0;

  core_set_watcher_userdata(io, co);
  core_io_init(io, IO_ACCEPT_EX, fd, EV_READ);
  core_io_start(CORE_LOOP_ io);
  return 1;
}

static int tcp_connect(lua_State *L){
  core_io *io = (core_io *) luaL_testudata(L, 1, "__TCP__");
  if(!io) return 0;

  /* socket文件描述符 */
  int fd = lua_tointeger(L, 2);
  if (0 >= fd)
    return 0;

  /* 回调协程 */
  lua_State *co = lua_tothread(L, 3);
  if (!co)
    return 0;

  core_set_watcher_userdata(io, co);
  core_io_init(io, IO_CONNECT, fd, EV_READ | EV_WRITE);
  core_io_start(CORE_LOOP_ io);
  return 0;
}

static int tcp_sslconnect(lua_State *L){

  SSL *ssl = (SSL*) lua_touserdata(L, 1);
  if (!ssl)
    return 0;

  int reason = SSL_get_error(ssl, SSL_do_handshake(ssl));
  /* 握手结束 -> 握手成功 */
  if (reason == SSL_ERROR_NONE){
    lua_pushboolean(L, 1);
    return 1;
  }
  /* 需要再进一步交互 */
  if (SSL_ERROR_WANT_READ == reason || SSL_ERROR_WANT_WRITE == reason){
    lua_pushnil(L);
    lua_pushinteger(L, reason - 1);
    return 2;
  }
  /* 握手失败 */
  return 0;
}

static int tcp_start(lua_State *L){
  core_io *io = (core_io *) luaL_testudata(L, 1, "__TCP__");
  if(!io)
    return 0;

  /* socket文件描述符 */
  int fd = lua_tointeger(L, 2);
  if (0 >= fd)
    return 0;

  /* 监听事件 */
  int events = lua_tointeger(L, 3);
  if (0 >= events || events > 3)
    return 0;

  /* 回调协程 */
  lua_State *co = lua_tothread(L, 4);
  if (!co)
    return 0;

  core_set_watcher_userdata(io, co);
  core_io_init(io, TCP_IO_CB, fd, events);
  core_io_start(CORE_LOOP_ io);
  return 0;
}

// 设置SSL客户端的SNI特性
static int ssl_set_connect_server(lua_State *L) {
  SSL *ssl = (SSL*) lua_touserdata(L, 1);
  if (!ssl)
    return luaL_error(L, "Invalid SSL ssl.");

  size_t size = 0;
  const char *hostname = (const char *)luaL_checklstring(L, 2, &size);
  if (!hostname || size < 1)
    return luaL_error(L, "Invalid host name.");

#if defined(SSL_set_tlsext_host_name)
  SSL_set_tlsext_host_name(ssl, hostname);
#endif

  return 1;
}

static int ssl_set_connect_mode(lua_State *L) {
  SSL *ssl = (SSL*) lua_touserdata(L, 1);
  if (!ssl)
    return luaL_error(L, "Invalid SSL ssl.");

  SSL_CTX *ctx = (SSL_CTX*) lua_touserdata(L, 2);
  if (!ctx)
    return luaL_error(L, "Invalid SSL_CTX ctx.");

  SSL_set_connect_state(ssl);

  return 1;
}

static int ssl_set_accept_mode(lua_State *L) {
  SSL *ssl = (SSL*) lua_touserdata(L, 1);
  if (!ssl)
    return luaL_error(L, "Invalid SSL ssl.");

  SSL_CTX *ctx = (SSL_CTX*) lua_touserdata(L, 2);
  if (!ctx)
    return luaL_error(L, "Invalid SSL_CTX ctx.");

  SSL_set_accept_state(ssl);

  return 1;
}

// 加载证书
static int ssl_set_certificate(lua_State *L) {
  SSL *ssl = (SSL*) lua_touserdata(L, 1);
  if (!ssl)
    return luaL_error(L, "Invalid SSL ssl.");

  SSL_CTX *ctx = (SSL_CTX*) lua_touserdata(L, 2);
  if (!ctx)
    return luaL_error(L, "Invalid SSL_CTX ctx.");

  size_t size = 0;
  const char* path = luaL_checklstring(L, 3, &size);
  if (!path || size < 1)
    return luaL_error(L, "Invalid cert path");

  // 为SSL与SSL_CTX设置证书, 如果两种加载都失败则返回失败.
  if (1 != SSL_use_certificate_file(ssl, path, SSL_FILETYPE_PEM))
    return luaL_error(L, "ssl ssl_set_certificate loading cert failed.");

  if (1 != SSL_CTX_use_certificate_file(ctx, path, SSL_FILETYPE_PEM))
    return luaL_error(L, "ssl_ctx ssl_set_certificate loading cert failed.");

  return 1;
}

// 加载私钥
static int ssl_set_privatekey(lua_State *L) {
  SSL *ssl = (SSL*) lua_touserdata(L, 1);
  if (!ssl)
    return luaL_error(L, "Invalid SSL ssl.");

  SSL_CTX *ctx = (SSL_CTX*) lua_touserdata(L, 2);
  if (!ctx)
    return luaL_error(L, "Invalid SSL_CTX ctx.");

  size_t size = 0;
  const char* path = luaL_checklstring(L, 3, &size);
  if (!path || size < 1)
    return luaL_error(L, "Invalid cert path");

  // 为SSL与SSL_CTX设置私钥, 如果两种加载都失败则返回失败.
  if (1 != SSL_use_PrivateKey_file(ssl, path, SSL_FILETYPE_PEM) && 1 != SSL_use_RSAPrivateKey_file(ssl, path, SSL_FILETYPE_PEM))
    return luaL_error(L, "ssl ssl_set_privatekey loading private_key or rsa_private_key failed.");

  if (1 != SSL_CTX_use_PrivateKey_file(ctx, path, SSL_FILETYPE_PEM) && 1 != SSL_CTX_use_RSAPrivateKey_file(ctx, path, SSL_FILETYPE_PEM))
      return luaL_error(L, "ssl_ctx ssl_set_privatekey loading private key or rsa_private_key failed.");

  return 1;
}

// 如果私钥有安装密钥, 则再这里设置
static int ssl_set_userdata_key(lua_State *L) {
  SSL *ssl = (SSL*) lua_touserdata(L, 1);
  if (!ssl)
    return luaL_error(L, "Invalid SSL ssl.");

  SSL_CTX *ctx = (SSL_CTX*) lua_touserdata(L, 2);
  if (!ctx)
    return luaL_error(L, "Invalid SSL_CTX ctx.");

  size_t size = 0;
  const char* password = luaL_checklstring(L, 3, &size);
  if (!password || size < 1)
    return 1;

  // SSL_set_default_passwd_cb_userdata(ssl, (void*)password);
  SSL_CTX_set_default_passwd_cb_userdata(ctx, (void*)password);
  return 1;
}

// 验证证书与私钥是否有效
static int ssl_verify(lua_State *L) {
  SSL *ssl = (SSL*) lua_touserdata(L, 1);
  if (!ssl)
    return luaL_error(L, "Invalid SSL ssl.");

  SSL_CTX *ctx = (SSL_CTX*) lua_touserdata(L, 2);
  if (!ctx)
    return luaL_error(L, "Invalid SSL_CTX ctx.");

  // 检查证书与私钥是否一致.
  if (1 != SSL_check_private_key(ssl) || 1 != SSL_CTX_check_private_key(ctx))
    return 0;

  lua_pushboolean(L, 1);
  return 1;
}

static int ssl_set_alpn(lua_State *L) {
  SSL *ssl = (SSL*) lua_touserdata(L, 1);
  if (!ssl)
    return luaL_error(L, "Invalid SSL ssl.");

  SSL_CTX *ctx = (SSL_CTX*) lua_touserdata(L, 2);
  if (!ctx)
    return luaL_error(L, "Invalid SSL_CTX ctx.");

  size_t lsize = 0;
  const char *str = luaL_checklstring(L, 3, &lsize);
  if (!str || lsize < 1)
    return 0;

#if OPENSSL_VERSION_NUMBER >= 0x10002000L
  SSL_set_alpn_protos(ssl, (const unsigned char *)str, lsize);
  SSL_CTX_set_alpn_protos(ctx, (const unsigned char *)str, lsize);
#endif // OPENSSL_VERSION_NUMBER >= 0x10002000L

  return 1;
}

static int ssl_get_alpn(lua_State *L) {
  SSL *ssl = (SSL*) lua_touserdata(L, 1);
  if (!ssl)
    return luaL_error(L, "Invalid SSL ssl.");

  SSL_CTX *ctx = (SSL_CTX*) lua_touserdata(L, 2);
  if (!ctx)
    return luaL_error(L, "Invalid SSL_CTX ctx.");

  uint32_t len = 0;
  const uint8_t *data = NULL;
#if OPENSSL_VERSION_NUMBER >= 0x10002000L
  SSL_get0_alpn_selected(ssl, (const uint8_t **)&data, (unsigned int *)&len);
#endif // OPENSSL_VERSION_NUMBER >= 0x10002000L
  if (!data || len < 1)
    return 0;
  lua_pushlstring(L, (const char *)data, len);
  return 1;
}

static int ssl_new(lua_State *L){
  SSL_CTX *ssl_ctx = SSL_CTX_new(SSLv23_method());
  if (!ssl_ctx)
    return 0;

  SSL *ssl = SSL_new(ssl_ctx);
  if (!ssl)
    return 0;

  lua_pushlightuserdata(L, (void*) ssl);
  lua_pushlightuserdata(L, (void*) ssl_ctx);
  return 2;
}

static int ssl_set_fd(lua_State *L) {

  SSL *ssl = (SSL*) lua_touserdata(L, 1);
  if (!ssl)
    return luaL_error(L, "Invalid SSL ssl.");

  int fd = lua_tointeger(L, 2);

  SSL_set_fd(ssl, fd);
  SSL_set_connect_state(ssl);
  return 1;
}

static int ssl_new_fd(lua_State *L){

  int fd = lua_tointeger(L, 1);

  SSL_CTX *ssl_ctx = SSL_CTX_new(SSLv23_method());
  if (!ssl_ctx)
    return 0;

  SSL *ssl = SSL_new(ssl_ctx);
  if (!ssl)
    return 0;

  SSL_set_fd(ssl, fd);
  SSL_set_connect_state(ssl);
  lua_pushlightuserdata(L, (void*) ssl);
  lua_pushlightuserdata(L, (void*) ssl_ctx);
  return 2;
}

static int ssl_free(lua_State *L){
  SSL *ssl = (SSL*) lua_touserdata(L, 1);
  if (ssl)
    SSL_free(ssl); // 销毁基于ctx的ssl对象;
  SSL_CTX *ssl_ctx = (SSL_CTX*) lua_touserdata(L, 2);
  if (ssl_ctx)
    SSL_CTX_free(ssl_ctx); // 销毁ctx上下文;
  return 0;
}

static int tcp_new(lua_State *L){
  core_io *io = (core_io *) lua_newuserdata(L, sizeof(core_io));
  if(!io)
    return 0;
  luaL_setmetatable(L, "__TCP__");
  return 1;
}


static int tcp_stop(lua_State *L){
  core_io *io = (core_io *) luaL_testudata(L, 1, "__TCP__");
  if(!io)
    return 0;
  core_io_stop(CORE_LOOP_ io);
  return 0;
}

static int tcp_close(lua_State *L){
  int fd = lua_tointeger(L, 1);
  if (fd && fd > 0)
    close(fd);
  return 0;
}

/* 修改写缓冲区大小 */
static int tcp_set_write_buf(lua_State *L) {
  int fd = lua_tointeger(L, 1);
  if (fd < 0)
    return 0;
  int bsize = lua_tointeger(L, 2);
  if (bsize < (1 << 16) || bsize > (1 << 20))
    return 0;

#if defined(SO_SNDBUF)
  if (-1 == setsockopt(fd, SOL_SOCKET, SO_SNDBUF, &bsize, sizeof(socklen_t)))
    return 0;
#endif
  
  return 1;
}

/* 修改读缓冲区大小 */
static int tcp_set_read_buf(lua_State *L) {
  int fd = lua_tointeger(L, 1);
  if (fd < 0)
    return 0;
  int bsize = lua_tointeger(L, 2);
  if (bsize < (1 << 16) || bsize > (1 << 20))
    return 0;

#if defined(SO_RCVBUF)
  if (-1 == setsockopt(fd, SOL_SOCKET, SO_RCVBUF, &bsize, sizeof(socklen_t)))
    return 0;
#endif

  return 1;
}

LUAMOD_API int luaopen_tcp(lua_State *L){
  luaL_checkversion(L);
  /* 添加SSL支持 */
  SSL_library_init();
  // SSL_load_error_strings();
  // ERR_load_crypto_strings();
  // OpenSSL_add_ssl_algorithms();
  // CRYPTO_set_mem_functions(xmalloc, xrealloc, xfree);
  /* 添加SSL支持 */
  luaL_newmetatable(L, "__TCP__");
  lua_pushstring (L, "__index");
  lua_pushvalue(L, -2);
  lua_rawset(L, -3);
  lua_pushliteral(L, "__mode");
  lua_pushliteral(L, "kv");
  lua_rawset(L, -3);
  luaL_Reg tcp_libs[] = {
    {"read", tcp_read},
    {"write", tcp_write},
    {"peek", tcp_peek},
    {"sslpeek", tcp_sslpeek},
    {"ssl_read", tcp_sslread},
    {"ssl_write", tcp_sslwrite},
    {"stop", tcp_stop},
    {"start", tcp_start},
    {"close", tcp_close},
    {"listen", tcp_listen},
    {"listen_ex", tcp_listen_ex},
    {"connect", tcp_connect},
    {"ssl_connect", tcp_sslconnect},
    {"new", tcp_new},
    {"new_ssl", ssl_new},
    {"ssl_set_fd", ssl_set_fd},
    {"new_ssl_fd", ssl_new_fd},
    {"free_ssl", ssl_free},
    {"new_server_fd", new_server_fd},
    {"new_client_fd", new_client_fd},
    {"new_unixsock_fd", new_unixsock_fd},
    {"sendfile", tcp_sendfile},
    {"ssl_verify", ssl_verify},
    {"ssl_set_alpn", ssl_set_alpn},
    {"ssl_get_alpn", ssl_get_alpn},
    {"tcp_set_read_buf", tcp_set_read_buf},
    {"tcp_set_write_buf", tcp_set_write_buf},
    {"ssl_set_accept_mode", ssl_set_accept_mode},
    {"ssl_set_connect_mode", ssl_set_connect_mode},
    {"ssl_set_privatekey", ssl_set_privatekey},
    {"ssl_set_certificate", ssl_set_certificate},
    {"ssl_set_userdata_key", ssl_set_userdata_key},
    {"ssl_set_connect_server", ssl_set_connect_server},
    {NULL, NULL}
  };
  luaL_setfuncs(L, tcp_libs, 0);
  luaL_newlib(L, tcp_libs);
  return 1;
}
