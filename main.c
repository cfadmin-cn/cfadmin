#include "stdio.h"
#include "stdlib.h"

#include "ev.h"

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

// void
// IO_CB(EV_P_ ev_io *io, int revent){
// 	char str[1024];
// 	memset(str, 0, 1024);
// 	printf("len = %d, data = %s", read(io->fd, str, 1024), str);
// 	ev_io_stop(EV_DEFAULT_ io);
// 	printf("1\n");
// 	ev_io_stop(EV_DEFAULT_ io);
// 	printf("2\n");
// 	ev_io_stop(EV_DEFAULT_ io);
// 	printf("3\n");
// 	ev_io_stop(EV_DEFAULT_ io);
// 	printf("4\n");
// }

int main(int argc, char const *argv[])
{
	// lua_State *L = luaL_newstate();
	// if (!L) return -1;
	// luaL_openlibs(L);

	// int status = luaL_loadstring(L, "function test(...) print('哈哈') end return coroutine.create(test)");
	// if (status != LUA_OK){
	// 	printf("error:%s\n", lua_tostring(L, -1));
	// 	return -1;
	// }
	// int ret = lua_resume(L, NULL, 0);
	// if (ret > 1){
	// 	printf("error:%s\n", lua_tostring(L, -1));
	// 	return -1;
	// }
	// lua_State *co = lua_tothread(L, 1);
	// ret = lua_resume(co, NULL, 0);
	// if (ret > 1){
	// 	printf("error:%s\n", lua_tostring(L, -1));
	// 	return -1;
	// }
	
	// ev_io io;
	// ev_io_init(&io, IO_CB, 1, EV_READ);
	// ev_io_start(EV_DEFAULT_ &io);

	// ev_run(EV_DEFAULT_ 0);
	return 0;
}