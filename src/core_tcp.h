#ifndef __CORE_TCP__
#define __CORE_TCP__

#include "../src/core_sys.h"
#include "../src/core_memory.h"
#include "../src/core_ev.h"

#define SERVER 0
#define CLIENT 1

SSL_CTX *ctx;

int new_tcp_fd(lua_State *L);

int tcp_get_fd(lua_State *L);

int tcp_new(lua_State *L);

int tcp_stop(lua_State *L);

int tcp_listen(lua_State *L);

int tcp_connect(lua_State *L);

int tcp_sslconnect(lua_State *L);

int tcp_start(lua_State *L);

int tcp_close(lua_State *L);

int tcp_read(lua_State *L);

int tcp_write(lua_State *L);

int tcp_sslread(lua_State *L);

int tcp_sslwrite(lua_State *L);

int ssl_new(lua_State *L);

int ssl_free(lua_State *L);

int luaopen_tcp(lua_State *L);



static const luaL_Reg tcp_libs[] = {
	{"read", tcp_read},
	{"write", tcp_write},
	{"ssl_read", tcp_sslread},
	{"ssl_write", tcp_sslwrite},
	{"stop", tcp_stop},
	{"start", tcp_start},
	{"close", tcp_close},
	{"listen", tcp_listen},
	{"connect", tcp_connect},
	{"ssl_connect", tcp_sslconnect},
	{"new", tcp_new},
	{"new_ssl", ssl_new},
	{"free_ssl", ssl_free},
	{"get_fd", tcp_get_fd},
	{"new_tcp_fd", new_tcp_fd},
	{NULL, NULL}
};

#endif