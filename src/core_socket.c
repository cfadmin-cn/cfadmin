#include "core_socket.h"

int /* 非阻塞 */
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

int /* 初始化套接字 */
tcp_server(char *ipaddr, int port){
	errno = 0;
	/* 建立socket*/
	int sockfd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
	if (0 >= sockfd) return 1;

	/* 设置非阻塞 */
	non_blocking(sockfd);

    int enable = 1;

     /* 地址/端口重用 */
    setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &enable, sizeof(enable));
    
     /* 关闭小包延迟合并算法 */
	setsockopt(sockfd, SOL_SOCKET, TCP_NODELAY, &enable, sizeof(enable));


	struct sockaddr_in server_addr;
	memset(&server_addr, 0, sizeof(server_addr));

	server_addr.sin_family = AF_INET;
	server_addr.sin_port = htons(port);
	server_addr.sin_addr.s_addr = INADDR_ANY;

	int bind_siccess = bind(sockfd, (struct sockaddr *)&server_addr, sizeof(struct sockaddr));
	if (0 > bind_siccess) {
		LOG("ERROR", "绑定套接字失败.");
		return -1; /* 绑定套接字失败 */
	}
	
	int listen_success = listen(sockfd, 512);
	if (0 > listen_success) {
		LOG("ERROR", "监听套接字失败.");
		return -1; /* 监听套接字失败 */
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
	luaL_buffinit(co, &buf);
	while (1) {
		char recvbuf[4096];
		size_t len = recv(io->fd, recvbuf, 4096, 0);
		if (0 > len) {
			if (errno == EINTR) continue; /* 重试 */
			if (errno == EAGAIN) break;
			ev_io_stop(EV_DEFAULT_ io); 
			close(io->fd); 
			free(io);
			return ;
		} /* 根据实际错误处理 */
		luaL_addlstring(&buf, recvbuf, len);
	}
	luaL_pushresult(&buf);
	int status = lua_resume(co, NULL, lua_gettop(co) > 0 ? lua_gettop(co) - 1 : 0);
}

void /* 接受链接 */
socket_accept(EV_P_ ev_io *io, int revents){
	struct sockaddr_in addr;
	memset(&addr, 0, sizeof(addr));

	char ipaddr[16];
	memset(&ipaddr, 0, sizeof(ipaddr));

	ev_io *clien_io = malloc(sizeof(ev_io));
	if (!clien_io) return ;

	socklen_t slen = sizeof(struct sockaddr_in);
	int client = accept(io->fd, (struct sockaddr*)&addr, &slen);
	if (0 > client) return ; /* 无视 accept 错误 */

	lua_State *co = (lua_State *) ev_get_watcher_userdata(io);

	lua_pushinteger(co, io->fd);
	lua_pushstring(co, inet_ntoa(addr.sin_addr));

	/* 后期有需要, 可以考虑注册定时器管理连接生命周期 */
	// ev_once(client, EV_READ, -1, socket_listen, (void *)co);

	ev_set_watcher_userdata(clien_io, co);

	ev_io_init(clien_io, socket_listen, client, EV_READ);

	ev_io_start(EV_DEFAULT_ clien_io);
}

int /* 接受数据 */
io_recv(lua_State *L){
	return 1;
}

int /* 发送数据 */
io_send(lua_State *L){
	return 1;
}

int
io_listen(lua_State *L){
	/* port验证 */
	int port = lua_tointeger(L, -2);
	if (0 >= port) return 1;

	/* 回调方法验证 */
	if (lua_type(L, 2) != LUA_TFUNCTION) return 1;

	int sockfd = tcp_server("0.0.0.0", port);
	if (0 > sockfd) return 1;

	lua_State *co = lua_newthread(L);
	if (!co) return 1;

	lua_pop(L, 1);

	lua_xmove(L, co, 1);

	ev_io *io = malloc(sizeof(ev_io));
	if (!io) return 1;

	ev_set_watcher_userdata(io, co);

	ev_io_init(io, socket_accept, sockfd, EV_READ);

	ev_io_start(EV_DEFAULT_ io);

	/* 清空栈 */
	lua_settop(L, 0);

	return 0;
}
