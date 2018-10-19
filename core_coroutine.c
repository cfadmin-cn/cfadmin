#include "core_coroutine.h"



int
non_blocking(int socket){
	return fcntl(socket, F_SETFL, fcntl(socket, F_GETFL, 0) | O_NONBLOCK);
}

int
tcp_server(char *ipaddr, int port){
	/* 建立socket*/
	int sockfd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
	if (0 >= sockfd) return 1;

	/* 设置非阻塞 */
	non_blocking(sockfd);

    int reuse = 1; /* 地址/端口重用 */
    setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, (const char*)&reuse, sizeof(reuse));

	struct sockaddr_in server_addr;
	memset(&server_addr, 0, sizeof(struct sockaddr_in));

	server_addr.sin_family = AF_INET;
	server_addr.sin_port = port;
	server_addr.sin_addr.s_addr = INADDR_ANY;

	int bind_siccess = bind(sockfd, (struct sockaddr *)&server_addr, sizeof(struct sockaddr *));
	if (0 >= bind_siccess) return -1; /* 绑定套接字失败 */
	
	int listen_success = listen(sockfd, 512);
	if (0 >= listen_success) return -1; /* 监听套接字失败 */

	return sockfd;
}

void /* 接受数据 */
ev_recv(EV_P_ ev_io *io, int revents){}

void /* 发送数据 */
ev_send(EV_P_ ev_io *io, int revents){}

void /* 接受链接 */
ev_accept(EV_P_ ev_io *io, int revents){
	printf("ev_accept...\n");
	if (ev_have_watcher_userdata(io)){
		lua_State *co = (lua_State *)ev_get_watcher_userdata(io);
		int status = lua_resume(co, NULL, lua_gettop(co) > 0 ? lua_gettop(co) - 1 : 0);
	}
	ev_io_stop(EV_DEFAULT_ io);
	free(io);
}

int
io_read(lua_State *L){
	return 1;
}

int
io_write(lua_State *L){
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
	if (!sockfd) return 1;

	lua_State *co = lua_newthread(L);
	if (!co) return 1;

	lua_pop(L, 1);

	lua_xmove(L, co, 1);

	ev_io *io = malloc(sizeof(ev_io));
	if (!io) return 1;

	ev_set_watcher_userdata(io, co);

	ev_io_init(io, ev_accept, sockfd, EV_READ);

	ev_io_start(EV_DEFAULT_ io);

	/* 清空栈 */
	lua_settop(L, 0);

	return 0;
}

int
io_close(lua_State *L){
	return 1;
}



/* === 定时器 === */
void
timeout_cb(EV_P_ ev_timer *timer, int revents){
	if (ev_have_watcher_userdata(timer)){
		lua_State *co = (lua_State *)ev_get_watcher_userdata(timer);
		int status = lua_resume(co, NULL, lua_gettop(co) > 0 ? lua_gettop(co) - 1 : 0);
	}
	ev_timer_stop(EV_DEFAULT_ timer);
	free(timer);
}

int
timer_timeout(lua_State *L){
	lua_Number timeout = lua_tonumber(L, 1);
	if (!timeout || 0. > timeout) return 1;
	
	if (lua_type(L, 2) != LUA_TFUNCTION) return 1;

	ev_timer *timer = malloc(sizeof(ev_timer));
	if (!timer) return 1;

	lua_State *co = lua_newthread(L);
	if (!timer) return 1;

	lua_pop(L, 1);

	lua_xmove(L, co, 1);

	ev_set_watcher_userdata(timer, co);

	ev_timer_init(timer, timeout_cb, timeout, 0);

	ev_timer_start(EV_DEFAULT_ timer);
	
	lua_settop(L, 0);
	return 0;
}

void
lua_openlibs(lua_State *L){
	luaL_openlibs(L);
	const luaL_Reg timer_libs[] = {
		{"timeout", timer_timeout},
		{NULL, NULL}
	};

	const luaL_Reg socket_libs[] = {
		{"listen", io_listen},
		{"read", io_read},
		{"write", io_write},
		{"close", io_close},
		{NULL, NULL}
	};
	/* 注入socket模块 */
	luaL_newlib(L, socket_libs);
	lua_setglobal(L,"core_socket");

	/* 注入timer模块 */
	luaL_newlib(L, timer_libs);
	lua_setglobal(L,"core_timer");
}