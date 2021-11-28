#define LUA_LIB

#include <core.h>

static void CHILD_CB (core_loop *loop, ev_child *w, int revents){
	ev_child_stop(loop, w);
  lua_State *co = core_get_watcher_userdata(w);
  if (co) {
    lua_pushinteger(co, w->rpid);
    lua_pushinteger(co, w->rstatus);
    int status = CO_RESUME(co, NULL, lua_status(co) == LUA_YIELD ? lua_gettop(co) : lua_gettop(co) - 1);
		if (status != LUA_YIELD && status != LUA_OK){
			LOG("ERROR", lua_tostring(co, -1));
		}
  }
}

/* 监听子进程状态 */
static int lwatch(lua_State *L){
  core_child* child = lua_newuserdata(L, sizeof(core_child));
  core_child_init(child, CHILD_CB, luaL_checkinteger(L, 1), 0);
  core_child_start(core_default_loop(), child);
  core_set_watcher_userdata(child, (void*)lua_tothread(L, 2));
  return 1;
}

/* 发信号杀死子进程 */
static int lkill(lua_State *L){
  kill(luaL_checkinteger(L, 1), SIGQUIT);
  return 0;
}

LUAMOD_API int luaopen_child(lua_State *L) {
  luaL_checkversion(L);
  luaL_Reg child_libs[] = {
    {"watch", lwatch},
    {"kill", lkill},
    {NULL, NULL},
  };
  luaL_newlib(L, child_libs);
  return 1;
}