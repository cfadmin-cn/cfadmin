#ifndef __CORE_SOCKET__
#define __CORE_SOCKET__

#include "../src/core_sys.h"
#include "../src/core_memory.h"
#include "../src/core_ev.h"

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

#define SERVER 0
#define CLIENT 1

/* server 和 client 都共享这个数据结构 */
typedef struct Socket {
	lua_State *on_open;
	lua_State *on_message;
	lua_State *on_close;
	lua_State *on_error;
}Socket;

int io_listen(lua_State *L);

int io_stop(lua_State *L);

int io_new(lua_State *L);

static const luaL_Reg socket_libs[] = {
	{"listen", io_listen},
	{"stop", io_stop},
	{"new", io_new},
	{NULL, NULL}
};

#endif