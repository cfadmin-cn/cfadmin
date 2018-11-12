#include "core_udp.h"


int
udp_socket_new(const char *ipaddr, int port){

	errno = 0;
	/* 建立socket*/
	int sockfd = socket(AF_INET, SOCK_DGRAM, IPPROTO_TCP);
	if (0 >= sockfd) return 1;

	/* 设置非阻塞 */
	non_blocking(sockfd);

    int ENABLE = 1;

     /* 地址/端口重用 */
    setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &ENABLE, sizeof(ENABLE));
    
     /* 关闭小包延迟合并算法 */
	setsockopt(sockfd, SOL_SOCKET, TCP_NODELAY, &ENABLE, sizeof(ENABLE));


	struct sockaddr_in sock_addr;
	memset(&sock_addr, 0, sizeof(sock_addr));

	sock_addr.sin_family = AF_INET;
	sock_addr.sin_port = htons(port);
	sock_addr.sin_addr.s_addr = inet_addr(ipaddr);

	int connection = connect(sockfd, (struct sockaddr*)&sock_addr, sizeof(struct sockaddr));
	if (errno != EINPROGRESS){
		close(sockfd);
		return -1;
	}
	return sockfd;
}

void
UDP_IO_CB(EV_P_ ev_io *io, int revents){

}

void
UDP_IO_CONNECT(EV_P_ ev_io *io, int revents){

}


int
new_udp_fd(lua_State *L){

	ev_io *io = (ev_io *) luaL_testudata(L, 1, "__UDP__");
	if(!io) {lua_settop(L, 0); return 0;}

	const char *ip = lua_tostring(L, 2);
	if(!ip) {lua_settop(L, 0); return 0;}

	int port = lua_tointeger(L, 3);
	if(!port) {lua_settop(L, 0); return 0;}

	int fd = udp_socket_new(ip, port);
	if (0 >= fd) {lua_settop(L, 0); return 0;}

	lua_settop(L, 0);

	lua_pushinteger(L, fd);

	return 1;

}

int
udp_stop(lua_State *L){

	ev_io *io = (ev_io *) luaL_testudata(L, 1, "__TCP__");
	if(!io) return 0;

	ev_io_stop(EV_DEFAULT_ io);

	return 0;

}

int
udp_close(lua_State *L){

	ev_io *io = (ev_io *) luaL_testudata(L, 1, "__TCP__");
	if(!io) {
		close(lua_tointeger(L, 1));
		return 0;
	}

	ev_io_stop(EV_DEFAULT_ io);

	if (io->fd > 0) close(io->fd);

	return 0;

}

int
udp_connect(lua_State *L){

	ev_io *io = (ev_io *) luaL_testudata(L, 1, "__UDP__");
	if(!io) return 0;

	/* socket文件描述符 */
	int fd = lua_tointeger(L, 2);
	if (0 >= fd) return 0;

	/* 回调协程 */
	lua_State *co = lua_tothread(L, 3);
	if (!co) return 0;

	ev_set_watcher_userdata(io, co);

	ev_io_init(io, UDP_IO_CONNECT, fd, EV_READ | EV_WRITE);

	ev_io_start(EV_DEFAULT_ io);

	lua_settop(L, 1);

	return 1;

}


int
udp_new(lua_State *L){

	ev_io *io = (ev_io *) lua_newuserdata(L, sizeof(ev_io));

	if(!io) return 0;

	ev_init (io, UDP_IO_CB);

	io->fd = io->events	= 0x00;

	luaL_setmetatable(L, "__UDP__");

	return 1;

}