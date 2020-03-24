#define LUA_LIB

#include <core.h>

static inline
void SETSOCKETOPT(int sockfd) {
	int Enable = 1;

	int ret = 0;

	/* 设置非阻塞 */
	non_blocking(sockfd);

/* 地址重用 */
#ifdef SO_REUSEADDR
  ret = setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &Enable, sizeof(Enable));
  if (ret) {
    LOG("ERROR", "设置 SO_REUSEADDR 失败.");
    return _exit(-1);
  }
#endif

/* 端口重用 */
#ifdef SO_REUSEPORT
  ret = setsockopt(sockfd, SOL_SOCKET, SO_REUSEPORT, &Enable, sizeof(Enable));
  if (ret) {
    LOG("ERROR", "设置 SO_REUSEPORT 失败.");
    return _exit(-1);
  }
#endif

/* 开启IPV6与ipv4双栈 */
#ifdef IPV6_V6ONLY
  int No = 0;
  ret = setsockopt(sockfd, IPPROTO_IPV6, IPV6_V6ONLY, (void *)&No, sizeof(No));
  if (ret){
    LOG("ERROR", "IPV6_V6ONLY 关闭失败.");
    return _exit(-1);
  }
#endif

}

static int
udp_socket_new(const char *ipaddr, int port){
	errno = 0;
	/* 建立 UDP Socket */
	int sockfd = socket(AF_INET6, SOCK_DGRAM, IPPROTO_UDP);
	if (0 >= sockfd) return -1;

	SETSOCKETOPT(sockfd);

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
	if (ret == -1) {
		LOG("ERROR", strerror(errno));
		close(sockfd);
		return -1;
	}
	return sockfd;
}

static void
UDP_IO_CB(CORE_P_ core_io *io, int revents){

	int status = 0;

	if (revents & EV_ERROR) {
		LOG("ERROR", "Recevied a core_io object internal error from libev.");
		return ;
	}

	if (revents & EV_READ){
		lua_State *co = (lua_State *)core_get_watcher_userdata(io);
		if (lua_status(co) == LUA_YIELD || lua_status(co) == LUA_OK){
			status = CO_RESUME(co, NULL, lua_gettop(co) > 0 ? lua_gettop(co) - 1 : 0);
			if (status != LUA_YIELD && status != LUA_OK){
				LOG("ERROR", lua_tostring(co, -1));
			}
		}
	}
}

static int
udp_send(lua_State *L){

	int fd = lua_tointeger(L, 1);
	if (fd < 0) return 0;

	const char* data = lua_tostring(L, 2);
	if (!data) return 0;

	size_t len = lua_tointeger(L, 3);

	int wsize = write(fd, data, len);

	lua_pushinteger(L, wsize);

	return 1;

}

static int
udp_recv(lua_State *L){

	int fd = lua_tointeger(L, 1);
	if (fd < 0) return 0;

	char str[4096] = {0};

	int rsize = read(fd, str, 4096);

	if (rsize < 0) return 0;

	lua_pushlstring(L, str, rsize);

	lua_pushinteger(L, rsize);

	return 2;

}

static int
udp_connect(lua_State *L){

	const char *ip = lua_tostring(L, 1);
	if(!ip) return 0;

	int port = lua_tointeger(L, 2);
	if(!port) return 0;

	int fd = udp_socket_new(ip, port);

	if (0 >= fd) return 0;

	lua_pushinteger(L, fd > 0 ? fd : -1);

	return 1;

}

static int
udp_start(lua_State *L){

	core_io *io = (core_io *) luaL_testudata(L, 1, "__UDP__");
	if(!io) return 0;

	int fd = lua_tointeger(L, 2);
	if (fd < 0) return 0;

	/* 回调协程 */
	lua_State *co = lua_tothread(L, 3);
	if (!co) return 0;

	core_set_watcher_userdata(io, co);

	core_io_init (io, UDP_IO_CB, fd, EV_READ);

	core_io_start (CORE_LOOP_ io);

	return 0;

}

static int
udp_stop(lua_State *L){

	core_io *io = (core_io *) luaL_testudata(L, 1, "__UDP__");
	if(!io) return 0;

	core_io_stop(CORE_LOOP_ io);

	return 0;

}

static int
udp_close(lua_State *L){

	int fd = lua_tointeger(L, 1);

	if (fd && fd > 0) close(fd);

	return 0;

}



static int
udp_new(lua_State *L){

	core_io *io = (core_io *) lua_newuserdata(L, sizeof(core_io));

	if(!io) return 0;

	luaL_setmetatable(L, "__UDP__");

	return 1;

}

LUAMOD_API int
luaopen_udp(lua_State *L){

	luaL_checkversion(L);

    luaL_newmetatable(L, "__UDP__");
    lua_pushstring (L, "__index");
    lua_pushvalue(L, -2);
    lua_rawset(L, -3);
    lua_pushliteral(L, "__mode");
    lua_pushliteral(L, "kv");
    lua_rawset(L, -3);

	luaL_Reg udp_libs[] = {
		{"new", udp_new},
		{"close", udp_close},
	    {"start", udp_start},
	    {"stop", udp_stop},
		{"connect", udp_connect},
	    {"send", udp_send},
	    {"recv", udp_recv},
		{NULL, NULL}
	};
	luaL_setfuncs(L, udp_libs, 0);
	luaL_newlib(L, udp_libs);
	return 1;
}
