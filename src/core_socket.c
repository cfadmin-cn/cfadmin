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
			LOG("ERROR", "绑定套接字失败.");
			return -1; /* 绑定套接字失败 */
		}
		
		int listen_success = listen(sockfd, 512);
		if (0 > listen_success) {
			LOG("ERROR", "监听套接字失败.");
			return -1; /* 监听套接字失败 */
		}
	}

	if(type == CLIENT){
		sock_addr.sin_family = AF_INET;
		sock_addr.sin_port = htons(port);
		sock_addr.sin_addr.s_addr = inet_addr(ipaddr);

		int connection = connect(sockfd, (struct sockaddr*)&sock_addr, sizeof(struct sockaddr));
		if (0 <= connection || errno != EINPROGRESS){
			LOG("ERROR", "连接失败");
			return -1;
		}
	}
	return sockfd;
}

 void /* 读取数据 */
 socket_listen(EV_P_ ev_io *io, int revents){
 	errno = 0;
 	if (client_is_closed(io->fd)){ /* 探测虽然有一定的微弱损耗, 但是减少了无用的逻辑判断 */
 		LOG("INFO", "客户端关闭了连接");
 		ev_io_stop(EV_DEFAULT_ io);
 		close(io->fd);
 		free(io);
 	}
 	lua_State *co = (lua_State *) ev_get_watcher_userdata(io);
 	luaL_Buffer buf;
 	luaL_buffinitsize(co, &buf, 10);
 	while (1) {
 		char recvbuf[4096];
 		size_t len = recv(io->fd, recvbuf, 4096, 0);
 		if (0 > len) {
 			if (errno == EINTR) continue; /* 重试 */
 			if (errno == EAGAIN) break;
 			ev_io_stop(EV_DEFAULT_ io);
 			close(io->fd); free(io);
 			return ;
 		} /* 根据实际错误处理 */
 		luaL_addlstring(&buf, recvbuf, 4096);
 	}
 	luaL_pushresult(&buf);
 	int status = lua_resume(co, NULL, lua_gettop(co) > 0 ? lua_gettop(co) - 1 : 0);
 }

void /* 接受链接 */
socket_accept(EV_P_ ev_io *io, int revents){
	if (revents & EV_READ){
		struct sockaddr_in addr;
		memset(&addr, 0, sizeof(addr));

		socklen_t slen = sizeof(struct sockaddr_in);
		int client = accept(io->fd, (struct sockaddr*)&addr, &slen);
		if (0 > client) return ; /* 无视 accept 错误 */

		ev_io *clien_io = malloc(sizeof(ev_io));
		if (!clien_io) return ;

		lua_State *co = (lua_State *) ev_get_watcher_userdata(io);
		if (lua_status(co) == LUA_YIELD || lua_status(co) == LUA_OK){  /* 这里触发 on_open */
			lua_pushinteger(co, io->fd);

			lua_pushstring(co, inet_ntoa(addr.sin_addr));

			lua_resume(co, NULL, lua_gettop(co) > 0 ? lua_gettop(co) - 1 : 0);
		}

		if (lua_status(co) == LUA_YIELD){
			 ev_set_watcher_userdata(clien_io, lua_tothread(co, 1));

			 ev_io_init(clien_io, socket_listen, client, EV_READ);

			 ev_io_start(EV_DEFAULT_ clien_io);

			 lua_settop(co, 1);
		}
	}
}


int 
io_stop(lua_State *L){
	return 1;
}

int 
io_listen(lua_State *L){

	ev_io *io = (ev_io *) luaL_testudata(L, 1, "__IO__");
	if(!io) return 0;

	/* IP地址 */
	const char *ip = lua_tostring(L, 2);
	if (0 >= ip) return 0;

	/* 端口 */
	int port = lua_tointeger(L, 3);
	if (0 >= port) return 0;

	/* 回调协程 */
	lua_State *co = lua_tothread(L, 3);
	if(!co) return 0;

	int sockfd = tcp_socket_new(NULL, port, SERVER);
	if (sockfd) return 0;

	ev_set_watcher_userdata(io, co);

	ev_io_init(io, socket_accept, sockfd, EV_READ);

	ev_io_start(EV_DEFAULT_ io);

	lua_settop(L, 1);

	return 1;
}

int 
io_new(lua_State *L){
	ev_io *io = (ev_io*) lua_newuserdata(L, sizeof(ev_io));
	if(!io) {
		lua_settop(L, 0);
		return 0;
	}
	luaL_setmetatable(L, "__IO__");
	return 1;
}



