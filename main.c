#include "stdio.h"
#include "stdlib.h"
// #include <unistd.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <errno.h>

#include "ev.h"

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

int pp[2];
ev_timer Timer;
ev_io io;
ev_signal s;
int number = 0;

// void
// SIGNAL_CB(EV_P_ ev_signal *signal, int revents){
// 	printf("signal for sigpipe\n");
// }

// void
// TIMER_CB(EV_P_ ev_timer *Timer, int revent){
// 	errno = 0;
// 	int wsize = write(pp[1], "1", 1);
// 	if (wsize < 0) {
// 		if (errno == EPIPE) {
// 			printf("对端已经关闭\n");
// 			ev_timer_stop(EV_DEFAULT_ Timer);
// 			close(pp[1]);
// 		}
// 	}
// }

// void
// IO_CB(EV_P_ ev_io *io, int revents){
// 	errno = 0;
// 	char str[1024];
// 	memset(str, 0, 1024);
// 	int rsize = read(io->fd, str, 1024);
// 	printf("str = %s, errno = %d, rsize = %d, revents = %d\n", str, errno, rsize, revents);
// 	ev_io_stop(EV_DEFAULT_ io);
// 	close(pp[0]);
// }

// void
// TIMER_CB(EV_P_ ev_timer *Timer, int revent){
// 	errno = 0;
// 	int wsize = write(pp[1], "1", 1);
// 	if (wsize < 0) {
// 		if (errno == EPIPE) {
// 			printf("对端已经关闭\n");
// 			ev_timer_stop(EV_DEFAULT_ Timer);
// 			close(pp[1]);
// 			ev_unref (EV_A);
// 		}
// 	}
// }

// void
// IO_CB(EV_P_ ev_io *io, int revents){
// 	errno = 0;
// 	char str[1024];
// 	memset(str, 0, 1024);
// 	int rsize = read(io->fd, str, 1024);
// 	printf("str = %s, errno = %d, rsize = %d, revents = %d\n", str, errno, rsize, revents);
// 	ev_io_stop(EV_DEFAULT_ io);
// 	close(pp[0]);
// 	ev_unref (EV_A);
// }

ev_timer Timer1, Timer2;
void
TIMER_CB1(EV_P_ ev_timer *Timer, int revent){
	printf("timeout 1... remain : %f\n", ev_timer_remaining(EV_DEFAULT_ Timer));

	// Timer2.repeat = 0;
	// ev_timer_again(EV_DEFAULT_ Timer);
	ev_timer_stop(EV_DEFAULT_ &Timer2);
}

void
TIMER_CB2(EV_P_ ev_timer *Timer, int revent){
	printf("timeout 2... remain : %f\n", ev_timer_remaining(EV_DEFAULT_ Timer));
}

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

	// socketpair(PF_LOCAL, SOCK_STREAM, 0, pp);

	// ev_io_init(&io, IO_CB, pp[0], EV_READ);
	// ev_io_start(EV_DEFAULT_ &io);


	ev_timer_init(&Timer1, TIMER_CB1, 1, 1);
	ev_timer_init(&Timer2, TIMER_CB2, 2, 2);

	ev_timer_start(EV_DEFAULT_ &Timer1);
	ev_timer_start(EV_DEFAULT_ &Timer2);

	// ev_signal_init(&s, SIGNAL_CB, SIGPIPE);
	// ev_signal_start(EV_DEFAULT_ &s);

	ev_run(EV_DEFAULT_ 0);
	
	return 0;
}