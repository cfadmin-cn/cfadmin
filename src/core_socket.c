#include "core_socket.h"

int /* 设置非阻塞 */
non_blocking(int socket){
	return fcntl(socket, F_SETFL, fcntl(socket, F_GETFL, 0) | O_NONBLOCK);
}

int /* 探测客户端是否关闭了连接 */
client_is_closed(fd){
	char PEEK[1];
	while (1) {
		size_t len = recv(fd, PEEK, 1, MSG_PEEK);
		switch(len){
			case 0: return 1;	/* len为0的时候说明客户端关闭了连接 */
			case 1: return 0;	/* len大于0的时候说明客户端发送了数据 */
			default: continue;	/* 其他情况继续探测.*/
		}
	}
}

int
tcp_socket_new(const char *ipaddr, int port, int type){

	errno = 0;
	/* 建立socket*/
	int sockfd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
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

	if (type == SERVER){
		sock_addr.sin_family = AF_INET;
		sock_addr.sin_port = htons(port);
		sock_addr.sin_addr.s_addr = INADDR_ANY;

		int bind_siccess = bind(sockfd, (struct sockaddr *)&sock_addr, sizeof(struct sockaddr));
		if (0 > bind_siccess) {
			return -1; /* 绑定套接字失败 */
		}
		
		int listen_success = listen(sockfd, 512);
		if (0 > listen_success) {
			return -1; /* 监听套接字失败 */
		}
	}
	if(type == CLIENT){
		sock_addr.sin_family = AF_INET;
		sock_addr.sin_port = htons(port);
		sock_addr.sin_addr.s_addr = inet_addr(ipaddr);

		int connection = connect(sockfd, (struct sockaddr*)&sock_addr, sizeof(struct sockaddr));
		if (errno != EINPROGRESS){
			close(sockfd);
			return -1;
		}
	}
	return sockfd;
}

void
IO_CB(EV_P_ ev_io *io, int revents) {

	int status = 0;

	if (revents & EV_ERROR) {
		LOG("ERROR", "Recevied a ev_io object internal error from libev.");
		return ;
	}

	if (revents & EV_WRITE){
		lua_State *co = (lua_State *)ev_get_watcher_userdata(io);
		if (lua_status(co) == LUA_YIELD || lua_status(co) == LUA_OK){
			status = lua_resume(co, NULL, lua_gettop(co) > 0 ? lua_gettop(co) - 1 : 0);
			if (status != LUA_YIELD && status != LUA_OK){
				LOG("ERROR", lua_tostring(co, -1));
			}
		}
	}
	if (revents & EV_READ){
		lua_State *co = (lua_State *)ev_get_watcher_userdata(io);
		if (lua_status(co) == LUA_YIELD || lua_status(co) == LUA_OK){
			status = lua_resume(co, NULL, lua_gettop(co) > 0 ? lua_gettop(co) - 1 : 0);
			if (status != LUA_YIELD && status != LUA_OK){
				LOG("ERROR", lua_tostring(co, -1));
			}
		}
	}
}

void
IO_CONNECT(EV_P_ ev_io *io, int revents){

	int status = 0;

	if (revents & EV_READ && revents & EV_WRITE){
		lua_State *co = (lua_State *)ev_get_watcher_userdata(io);
		if (lua_status(co) == LUA_YIELD || lua_status(co) == LUA_OK){
			lua_pushboolean(co, 0);
			status = lua_resume(co, NULL, lua_gettop(co) > 0 ? lua_gettop(co) - 1 : 0);
			if (status != LUA_YIELD && status != LUA_OK){
				LOG("ERROR", lua_tostring(co, -1));
			}
		}
		return ;
	}
	
	if (revents & EV_WRITE){
		lua_State *co = (lua_State *)ev_get_watcher_userdata(io);
		if (lua_status(co) == LUA_YIELD || lua_status(co) == LUA_OK){
			lua_pushboolean(co, 1);
			status = lua_resume(co, NULL, lua_gettop(co) > 0 ? lua_gettop(co) - 1 : 0);
			if (status != LUA_YIELD && status != LUA_OK){
				LOG("ERROR", lua_tostring(co, -1));
			}
		}
		return ;
	}
}

void /* 接受链接 */
IO_ACCEPT(EV_P_ ev_io *io, int revents){

	if (revents & EV_READ){
		errno = 0;

		struct sockaddr_in addr;
		memset(&addr, 0, sizeof(addr));

		socklen_t slen = sizeof(struct sockaddr_in);
		int client = accept(io->fd, (struct sockaddr*)&addr, &slen);
		if (0 >= client) {
			LOG("INFO", strerror(errno));
			return ;
		}

		lua_State *co = (lua_State *) ev_get_watcher_userdata(io);
		if (lua_status(co) == LUA_YIELD || lua_status(co) == LUA_OK){

			lua_pushinteger(co, client);

			lua_pushstring(co, inet_ntoa(addr.sin_addr));

			int status = lua_resume(co, NULL, lua_status(co) == LUA_YIELD ? lua_gettop(co) : lua_gettop(co) - 1);
			if (status != LUA_YIELD && status != LUA_OK) {
				LOG("ERROR", lua_tostring(co, -1));
				LOG("ERROR", "Error Lua Accept Method");
			}
		}
	}

}

int
io_read(lua_State *L){

	errno = 0;

	ev_io *io = (ev_io *) luaL_testudata(L, 1, "__Socket__");
	if(!io) return 0;

	int bytes = lua_tointeger(L, 2);
	if (0 >= bytes) return 0;

	lua_settop(L, 0);

	for(;;){
		char str[bytes];
		int len = read(io->fd, str, bytes);
		if (len > 0) {
			lua_pushlstring(L, str, len);
			lua_pushinteger(L, len);
			break;
		}
		if (!len) {
			lua_pushnil(L);
			lua_pushinteger(L, -1);
			break;
		}
		if (errno == EINTR) continue;
		if (errno == EAGAIN) break;
		lua_pushnil(L);
		lua_pushinteger(L, -1);
		break;
	}
	return 2;
}

int
io_readall(lua_State *L){

	errno = 0;

	ev_io *io = (ev_io *) luaL_testudata(L, 1, "__Socket__");
	if(!io) return 0;

	lua_settop(L, 0);

	size_t Max = 0;

	for(;;){
		char str[1024] = {0};
		int len = read(io->fd, str, 1024);
		len >= 0 ? Max = Max + len : 0;
		if (len > 0) {
			lua_pushlstring(L, str, len);
			continue;
		}
		if (errno == EINTR) continue;
		if (errno == EAGAIN) break;
		lua_settop(L, 0);
		lua_pushnil(L);
		lua_pushinteger(L, -1);
		return 2;
	}
	lua_concat(L, lua_gettop(L));
	lua_pushinteger(L, Max);
	return 2;
}

int
io_write(lua_State *L){
	ev_io *io = (ev_io *) luaL_testudata(L, 1, "__Socket__");
	if(!io) return 0;
	const char *response = lua_tostring(L, 2);

	if (!response) return 0;

	lua_settop(L, 0);

	errno = 0;

	for(;;){

		int wsize = write(io->fd, response, strlen(response));
		if (wsize > 0) {
			lua_pushinteger(L, wsize);
			break;
		}

		if (wsize < 0){
			if (errno == EINTR) continue;
			if (errno == EAGAIN){
				lua_pushinteger(L, 0);
				break;
			}
			lua_pushnil(L);
			break;
		}
	}
	return 1;
}


int
io_get_fd(lua_State *L){

	ev_io *io = (ev_io *) luaL_testudata(L, 1, "__Socket__");

	if(!io) {
		lua_pushinteger(L, -1);
		return 1;
	}

	lua_pushinteger(L, io->fd > 0 ? io->fd : 0);

	return 1;

}

int
io_new_tcp_fd(lua_State *L){

	ev_io *io = (ev_io *) luaL_testudata(L, 1, "__Socket__");
	if(!io) {lua_settop(L, 0); return 0;}

	const char *ip = lua_tostring(L, 2);
	if(!ip) {lua_settop(L, 0); return 0;}

	int port = lua_tointeger(L, 3);
	if(!port) {lua_settop(L, 0); return 0;}

	int type = lua_tointeger(L, 4);
	if(type != SERVER && type != CLIENT) {lua_settop(L, 0); return 0;}

	int fd = tcp_socket_new(ip, port, type);
	if (0 >= fd) {lua_settop(L, 0); return 0;}

	lua_settop(L, 0);

	lua_pushinteger(L, fd);

	return 1;

}

int
io_stop(lua_State *L){

	ev_io *io = (ev_io *) luaL_testudata(L, 1, "__Socket__");
	if(!io) return 0;

	ev_io_stop(EV_DEFAULT_ io);

	return 0;

}

int
io_close(lua_State *L){

	ev_io *io = (ev_io *) luaL_testudata(L, 1, "__Socket__");
	if(!io) {
		close(lua_tointeger(L, 1));
		return 0;
	}

	ev_io_stop(EV_DEFAULT_ io);

	if (io->fd > 0) close(io->fd);

	return 0;

}

int
io_listen(lua_State *L){

	ev_io *io = (ev_io *) luaL_testudata(L, 1, "__Socket__");
	if(!io) return 0;

	/* socket文件描述符 */
	int fd = lua_tointeger(L, 2);
	if (0 >= fd) return 0;

	/* 回调协程 */
	lua_State *co = lua_tothread(L, 3);
	if (!co) return 0;

	ev_set_watcher_userdata(io, co);

	ev_io_init(io, IO_ACCEPT, fd, EV_READ);

	ev_io_start(EV_DEFAULT_ io);

	lua_settop(L, 1);

	return 1;

}

int
io_connect(lua_State *L){

	ev_io *io = (ev_io *) luaL_testudata(L, 1, "__Socket__");
	if(!io) return 0;

	/* socket文件描述符 */
	int fd = lua_tointeger(L, 2);
	if (0 >= fd) return 0;

	/* 回调协程 */
	lua_State *co = lua_tothread(L, 3);
	if (!co) return 0;

	ev_set_watcher_userdata(io, co);

	ev_io_init(io, IO_CONNECT, fd, EV_READ | EV_WRITE);

	ev_io_start(EV_DEFAULT_ io);

	lua_settop(L, 1);

	return 1;

}

int
io_start(lua_State *L){

	ev_io *io = (ev_io *) luaL_testudata(L, 1, "__Socket__");
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

	ev_set_watcher_userdata(io, co);

	ev_io_init(io, IO_CB, fd, events);

	ev_io_start(EV_DEFAULT_ io);

	lua_settop(L, 1);

	return 1;

}

int
io_new(lua_State *L){

	ev_io *io = (ev_io *) lua_newuserdata(L, sizeof(ev_io));

	if(!io) return 0;

	ev_init (io, IO_CB);

	io->fd = io->events	= 0x00;

	luaL_setmetatable(L, "__Socket__");

	return 1;

}
