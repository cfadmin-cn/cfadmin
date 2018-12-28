#define LUA_LIB

#include "../../src/core.h"

int
udp_socket_new(const char *ipaddr, int port){

	errno = 0;
	/* 建立socket*/
	int sockfd = socket(AF_INET, SOCK_DGRAM, 0);
	if (0 >= sockfd) return -1;

	/* 设置非阻塞 */
	non_blocking(sockfd);

    int ENABLE = 1;

     /* 地址/端口重用 */
    setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &ENABLE, sizeof(ENABLE));

	struct sockaddr_in sock_addr;
	memset(&sock_addr, 0, sizeof(sock_addr));

	sock_addr.sin_family = AF_INET;
	sock_addr.sin_port = htons(port);
	sock_addr.sin_addr.s_addr = inet_addr(ipaddr);

	connect(sockfd, (struct sockaddr*)&sock_addr, sizeof(struct sockaddr));

	return sockfd;
}

static void
UDP_IO_CB(CORE_P_ ev_io *io, int revents){

	int status = 0;

	if (revents & EV_ERROR) {
		LOG("ERROR", "Recevied a ev_io object internal error from libev.");
		return ;
	}

	if (revents & EV_READ){
		lua_State *co = (lua_State *)core_get_watcher_userdata(io);
		if (lua_status(co) == LUA_YIELD || lua_status(co) == LUA_OK){
			status = lua_resume(co, NULL, lua_gettop(co) > 0 ? lua_gettop(co) - 1 : 0);
			if (status != LUA_YIELD && status != LUA_OK){
				LOG("ERROR", lua_tostring(co, -1));
			}
		}
	}
}

int
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

int
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

int
udp_connect(lua_State *L){

	const char *ip = lua_tostring(L, 1);
	if(!ip) {lua_settop(L, 0); return 0;}

	int port = lua_tointeger(L, 2);
	if(!port) {lua_settop(L, 0); return 0;}

	int fd = udp_socket_new(ip, port);

	lua_pushinteger(L, fd > 0 ? fd : -1);

	return 1;

}

int
udp_start(lua_State *L){

	ev_io *io = (ev_io *) luaL_testudata(L, 1, "__UDP__");
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

int
udp_stop(lua_State *L){

	ev_io *io = (ev_io *) luaL_testudata(L, 1, "__UDP__");
	if(!io) return 0;

	core_io_stop(CORE_LOOP_ io);

	return 0;

}

int
udp_close(lua_State *L){

	int fd = lua_tointeger(L, 1);

	if (fd && fd > 0) close(fd);

	return 0;

}



int
udp_new(lua_State *L){

	ev_io *io = (ev_io *) lua_newuserdata(L, sizeof(ev_io));

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