#define LUA_LIB

#include <openssl/ssl.h>
#include <openssl/err.h>
#include <openssl/crypto.h>
#include "../../src/core.h"

#define SERVER 0
#define CLIENT 1

static inline
void SETSOCKETOPT(int sockfd, int mode){

  int Enable = 1;

  int ret = 0;

	/* 设置非阻塞 */
  non_blocking(sockfd);

/* 地址重用 */
#ifdef SO_REUSEADDR
  ret = setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &Enable, sizeof(Enable));
	if (ret) {
		LOG("ERROR", "设置 SO_REUSEADDR 失败.");
		return exit(-1);
	}
#endif

/* 端口重用 */
#ifdef SO_REUSEPORT
  if (mode == SERVER) {
  	ret = setsockopt(sockfd, SOL_SOCKET, SO_REUSEPORT, &Enable, sizeof(Enable));
  	if (ret) {
  		LOG("ERROR", "设置 SO_REUSEPORT 失败.");
  		return exit(-1);
  	}
  }
#endif

/* 关闭小包延迟合并算法 */
#ifdef TCP_NODELAY
	ret = setsockopt(sockfd, IPPROTO_TCP, TCP_NODELAY, &Enable, sizeof(Enable));
  if (ret){
    LOG("ERROR", "TCP_NODELAY 设置失败.");
    return exit(-1);
  }
#endif

/* 开启 TCP keepalive */
#ifdef SO_KEEPALIVE
  ret = setsockopt(sockfd, IPPROTO_TCP, SO_KEEPALIVE, &Enable , sizeof(Enable));
  if (ret){
    LOG("ERROR", "SO_KEEPALIVE 设置失败.");
    return exit(-1);
  }
#endif

/* 开启延迟Accept, 没数据来之前不回调accept */
#ifdef TCP_DEFER_ACCEPT
  if (mode == SERVER) {
    ret = setsockopt(sockfd, IPPROTO_TCP, TCP_DEFER_ACCEPT, &Enable, sizeof(Enable));
    if (ret){
      LOG("ERROR", "TCP_DEFER_ACCEPT 设置失败.");
      return exit(-1);
    }
  }
#endif

/* 设置 TCP keepalive 空闲时间 */
#ifdef TCP_KEEPIDLE
  int keepidle = 30;
  ret = setsockopt(sockfd, IPPROTO_TCP, TCP_KEEPIDLE, &keepidle , sizeof(keepidle));
  if (ret){
    LOG("ERROR", "TCP_KEEPIDLE 设置失败.");
    return exit(-1);
  }
#endif

/* 设置 TCP keepalive 探测总次数 */
#ifdef TCP_KEEPCNT
  int keepcount = 3;
  ret = setsockopt(sockfd, IPPROTO_TCP, TCP_KEEPCNT, &keepcount , sizeof(keepcount));
  if (ret){
    LOG("ERROR", "TCP_KEEPCNT 设置失败.");
    return exit(-1);
  }
#endif

/* 设置 TCP keepalive 每次探测间隔时间 */
#ifdef TCP_KEEPINTVL
  int keepinterval = 5;
  ret = setsockopt(sockfd, IPPROTO_TCP, TCP_KEEPINTVL, &keepinterval , sizeof(keepinterval));
  if (ret){
    LOG("ERROR", "TCP_KEEPINTVL 设置失败.");
    return exit(-1);
  }
#endif

/* 开启IPV6与ipv4双栈 */
#ifdef IPV6_V6ONLY
  int No = 0;
  ret = setsockopt(sockfd, IPPROTO_IPV6, IPV6_V6ONLY, (void *)&No, sizeof(No));
  if (ret){
    LOG("ERROR", "IPV6_V6ONLY 关闭失败.");
    return exit(-1);
  }
#endif

}

/* server fd */
static int
create_server_fd(int port, int backlog){
  errno = 0;
	/* 建立 TCP Server Socket */
	int sockfd = socket(AF_INET6, SOCK_STREAM, IPPROTO_TCP);
	if (0 >= sockfd) return -1;

	/* socket option set */
	SETSOCKETOPT(sockfd, SERVER);

	struct sockaddr_in6 SA;
  memset(&SA, 0x0, sizeof(SA));

	SA.sin6_family = AF_INET6;
	SA.sin6_port = htons(port);
	SA.sin6_addr = in6addr_any;

  /* 绑定套接字失败 */
	int bind_success = bind(sockfd, (struct sockaddr *)&SA, sizeof(SA));
	if (0 > bind_success) return -1;

  /* 监听套接字失败 */
	int listen_success = listen(sockfd, backlog);
	if (0 > listen_success) return -1;

	return sockfd;
}

/* client fd */
static int
create_client_fd(const char *ipaddr, int port){
  errno = 0;
	/* 建立 TCP Client Socket */
	int sockfd = socket(AF_INET6, SOCK_STREAM, IPPROTO_TCP);
	if (0 >= sockfd) return -1;

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
		close(sockfd);
		return -1;
  }
	return sockfd;
}


static void
TCP_IO_CB(CORE_P_ core_io *io, int revents) {

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

static void
IO_CONNECT(CORE_P_ core_io *io, int revents){

	if (revents & EV_ERROR) {
		LOG("ERROR", "Recevied a core_io object internal error from libev.");
		return ;
	}

	if (revents & EV_WRITE){
		lua_State *co = (lua_State *)core_get_watcher_userdata(io);
		if (lua_status(co) == LUA_YIELD || lua_status(co) == LUA_OK){
			int CONNECTED = 0, err = 0;
      socklen_t len = sizeof(socklen_t);
			if(getsockopt(io->fd, SOL_SOCKET, SO_ERROR, &err, (socklen_t*)&len) == 0 && err == 0) CONNECTED = 1;
			lua_pushboolean(co, CONNECTED);
			int status = CO_RESUME(co, NULL, 1);
			if (status != LUA_YIELD && status != LUA_OK){
				LOG("ERROR", lua_tostring(co, -1));
				core_io_stop(CORE_LOOP_ io);
			}
		}
	}

}

static void /* 接受链接 */
IO_ACCEPT(CORE_P_ core_io *io, int revents){

	if (revents & EV_READ){
		for(;;) {
			errno = 0;
			struct sockaddr_in6 SA;
			socklen_t slen = sizeof(SA);
      memset(&SA, 0x0, slen);
			int client = accept(io->fd, (struct sockaddr*)&SA, &slen);
			if (0 >= client) {
				if (errno != EWOULDBLOCK)
					LOG("INFO", strerror(errno));
				return ;
			}
      non_blocking(client); //在某些平台下, 这个socket是阻塞的.
			lua_State *co = (lua_State *) core_get_watcher_userdata(io);
			if (lua_status(co) == LUA_YIELD || lua_status(co) == LUA_OK){
				char buf[INET6_ADDRSTRLEN];
				inet_ntop(AF_INET6, &SA.sin6_addr, buf, INET6_ADDRSTRLEN);
				lua_pushinteger(co, client);
				lua_pushlstring(co, buf, strlen(buf));
				int status = CO_RESUME(co, NULL, lua_status(co) == LUA_YIELD ? lua_gettop(co) : lua_gettop(co) - 1);
				if (status != LUA_YIELD && status != LUA_OK) {
					LOG("ERROR", lua_tostring(co, -1));
					LOG("ERROR", "Error Lua Accept Method");
				}
			}
		}
	}
}

struct io_sendfile {
  uint32_t offset;
  uint32_t fd;
  uint64_t pos;
  lua_State *L;
};

static void
IO_SENDFILE(CORE_P_ core_io *io, int revents){
  if (revents & EV_WRITE){
    errno = 0;
    struct io_sendfile *sf = core_get_watcher_userdata(io);

#ifdef EV_USE_KQUEUE
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
#endif

#ifdef EV_USE_EPOLL
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
#endif

#ifdef EV_USE_SELECT
    char buf[sf->offset];
    for (;;) {
      memset(buf, 0x0, sf->offset);
      int rBytes = read(sf->fd, buf, sf->offset);
      if (0 == rBytes) { lua_pushboolean(sf->L, 1); break; } // 所有数据写入发送完毕.
      int wBytes = write(io->fd, buf, rBytes);
      if (wBytes <= 0) {
        /* 如果写入失败后需要重试, 则需要先恢复到上次写入位置*/
        lseek(sf->fd, lseek(sf->fd, 0, SEEK_CUR) - rBytes, SEEK_SET);
        if (errno == EINTR) continue ;
        if (errno == EWOULDBLOCK) return;
        lua_pushboolean(sf->L, 0);
        break;
      }
      // 如果文件发送字符数量小于读取数量, 就需要重新设置读写位置。
      if (rBytes > wBytes) lseek(sf->fd, lseek(sf->fd, 0, SEEK_CUR) - (rBytes - wBytes), SEEK_SET);
    }
#endif
    core_set_watcher_userdata(io, NULL);
    int status = CO_RESUME(sf->L, NULL, lua_status(sf->L) == LUA_YIELD ? lua_gettop(sf->L) : lua_gettop(sf->L) - 1);
    if (status != LUA_YIELD && status != LUA_OK) {
      LOG("ERROR", lua_tostring(sf->L, -1));
      LOG("ERROR", "Error Lua SENDFILE Method");
    }
    close(sf->fd); xfree(sf);
  }
}

static int
tcp_sendfile(lua_State *L){
  core_io *io = (core_io *) luaL_testudata(L, 1, "__TCP__");
  lua_State *t = lua_tothread(L, 2);
  const char* path = luaL_checkstring(L, 3);
  lua_Integer iofd = luaL_checkinteger(L, 4);
  lua_Integer offset = luaL_checkinteger(L, 5);

  int fd = open(path, O_RDONLY);
  if (0 > fd) return luaL_error(L, strerror(errno));

  struct io_sendfile *sf = xmalloc(sizeof(struct io_sendfile));
  sf->pos = 0;
  sf->fd = fd;
  sf->offset = offset;
  sf->L = t;

  core_set_watcher_userdata(io, sf);
  core_io_init(io, IO_SENDFILE, iofd, EV_WRITE);
  core_io_start(CORE_LOOP_ io);
  return 1;
}

static int
tcp_read(lua_State *L){

	errno = 0;

	int fd = lua_tointeger(L, 1);
	if (0 >= fd) return 0;

	int bytes = lua_tointeger(L, 2);
	if (0 >= bytes) return 0;

	do {
		char str[bytes];
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

	return 0;
}

static int
tcp_sslread(lua_State *L){

	errno = 0;

	SSL *ssl = lua_touserdata(L, 1);
	if (!ssl) return 0;

	int bytes = lua_tointeger(L, 2);
	if (0 >= bytes) return 0;

	do {
		char str[bytes];
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

static int
tcp_write(lua_State *L){

	errno = 0;

	int fd = lua_tointeger(L, 1);
	if (0 >= fd) return 0;

	const char *response = lua_tostring(L, 2);
	if (!response) return 0;

	int resp_len = lua_tointeger(L, 3);

	do {

		int wsize = write(fd, response, resp_len);

		if (wsize > 0) { lua_pushinteger(L, wsize); return 1; }

		if (wsize < 0){
			if (errno == EINTR) continue;
			if (errno == EWOULDBLOCK){ lua_pushinteger(L, 0); return 1;}
		}

	} while (0);

	return 0;
}

static int
tcp_sslwrite(lua_State *L){

	SSL *ssl = lua_touserdata(L, 1);
	if (!ssl) return 0;

	const char *response = lua_tostring(L, 2);
	if (!response) return 0;

	int resp_len = lua_tointeger(L, 3);

	errno = 0;

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

static int
new_server_fd(lua_State *L){
	const char *ip = lua_tostring(L, 1);
	if(!ip) return 0;

	int port = lua_tointeger(L, 2);
	if(!port) return 0;

	int backlog = lua_tointeger(L, 3);

	int fd = create_server_fd(port, 0 >= backlog ? 128 : backlog);
	if (0 >= fd) return 0;

	lua_pushinteger(L, fd);

	return 1;
}

static int
new_client_fd(lua_State *L){
	const char *ip = lua_tostring(L, 1);
	if(!ip) return 0;

	int port = lua_tointeger(L, 2);
	if(!port) return 0;

	int fd = create_client_fd(ip, port);
	if (0 >= fd) return 0;

	lua_pushinteger(L, fd);

	return 1;
}

static int
tcp_listen(lua_State *L){
	core_io *io = (core_io *) luaL_testudata(L, 1, "__TCP__");
	if(!io) return 0;

	/* socket文件描述符 */
	int fd = lua_tointeger(L, 2);
	if (0 >= fd) return 0;

	/* 回调协程 */
	lua_State *co = lua_tothread(L, 3);
	if (!co) return 0;

	core_set_watcher_userdata(io, co);

	core_io_init(io, IO_ACCEPT, fd, EV_READ);

	core_io_start(CORE_LOOP_ io);

	return 0;
}

static int
tcp_connect(lua_State *L){

	core_io *io = (core_io *) luaL_testudata(L, 1, "__TCP__");
	if(!io) return 0;

	/* socket文件描述符 */
	int fd = lua_tointeger(L, 2);
	if (0 >= fd) return 0;

	/* 回调协程 */
	lua_State *co = lua_tothread(L, 3);
	if (!co) return 0;

	core_set_watcher_userdata(io, co);

	core_io_init(io, IO_CONNECT, fd, EV_READ | EV_WRITE);

	core_io_start(CORE_LOOP_ io);

	return 0;

}

static int
tcp_sslconnect(lua_State *L){

	SSL *ssl = (SSL*) lua_touserdata(L, 1);
	if (!ssl) return 0;

	int status = SSL_do_handshake(ssl);
	if (status >= 1) {
		lua_pushboolean(L, 1);
		return 1;
	}
  int ERR = SSL_get_error(ssl, status);
  // printf("status = %d, ERR = %d, SSL_ERROR_WANT_READ == %d, SSL_ERROR_WANT_WRITE == %d\n", status, ERR, SSL_ERROR_WANT_READ, SSL_ERROR_WANT_WRITE);
	if (SSL_ERROR_WANT_READ == ERR || SSL_ERROR_WANT_WRITE == ERR) {
		lua_pushnil(L);
		lua_pushinteger(L, ERR - 1);
		return 2;
	}
	return 0;

}

static int
tcp_start(lua_State *L){

	core_io *io = (core_io *) luaL_testudata(L, 1, "__TCP__");
	if(!io) return 0;

	/* socket文件描述符 */
	int fd = lua_tointeger(L, 2);
	if (0 >= fd) return 0;

	/* 监听事件 */
	int events = lua_tointeger(L, 3);
	if (0 >= events || events > 3) return 0;

	/* 回调协程 */
	lua_State *co = lua_tothread(L, 4);
	if (!co) return 0;

	core_set_watcher_userdata(io, co);

	core_io_init(io, TCP_IO_CB, fd, events);

	core_io_start(CORE_LOOP_ io);

	return 0;

}

static int
ssl_new(lua_State *L){

	int fd = lua_tointeger(L, 1);

	SSL_CTX *ssl_ctx = SSL_CTX_new(SSLv23_method());
	if (!ssl_ctx) return 0;

	SSL *ssl = SSL_new(ssl_ctx);
	if (!ssl) return 0;

	SSL_set_fd(ssl, fd);

	SSL_set_connect_state(ssl);

	lua_pushlightuserdata(L, (void*) ssl_ctx);

	lua_pushlightuserdata(L, (void*) ssl);

	return 2;
}

static int
ssl_free(lua_State *L){

	SSL_CTX *ssl_ctx = (SSL_CTX*) lua_touserdata(L, 1);
	if (ssl_ctx) SSL_CTX_free(ssl_ctx); // 销毁ctx上下文;

	SSL *ssl = (SSL*) lua_touserdata(L, 2);
	if (ssl) SSL_free(ssl); // 销毁基于ctx的ssl对象;

	return 0;
}

static int
tcp_new(lua_State *L){

	core_io *io = (core_io *) lua_newuserdata(L, sizeof(core_io));

	if(!io) return 0;

	luaL_setmetatable(L, "__TCP__");

	return 1;

}


static int
tcp_stop(lua_State *L){

	core_io *io = (core_io *) luaL_testudata(L, 1, "__TCP__");
	if(!io) return 0;

	core_io_stop(CORE_LOOP_ io);

	return 0;

}

static int
tcp_close(lua_State *L){

	int fd = lua_tointeger(L, 1);

	if (fd && fd > 0) close(fd);

	return 0;

}

LUAMOD_API int
luaopen_tcp(lua_State *L){
  luaL_checkversion(L);
  /* 添加SSL支持 */
  SSL_library_init();
  SSL_load_error_strings();
  // ERR_load_crypto_strings();
  // CRYPTO_set_mem_functions(xmalloc, xrealloc, xfree);
  // OpenSSL_add_ssl_algorithms();
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
    {"ssl_read", tcp_sslread},
    {"ssl_write", tcp_sslwrite},
    {"stop", tcp_stop},
    {"start", tcp_start},
    {"close", tcp_close},
    {"listen", tcp_listen},
    {"connect", tcp_connect},
    {"ssl_connect", tcp_sslconnect},
    {"new", tcp_new},
    {"new_ssl", ssl_new},
    {"free_ssl", ssl_free},
    {"new_server_fd", new_server_fd},
    {"new_client_fd", new_client_fd},
    {"sendfile", tcp_sendfile},
    {NULL, NULL}
  };
  luaL_setfuncs(L, tcp_libs, 0);
  luaL_newlib(L, tcp_libs);
  return 1;
}
