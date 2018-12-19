#define LUA_LIB

#include "../../src/core.h"


void
TASK_CB(int revents, void *args){
	if (revents & EV_TIMER){

		core_task *task = (core_task *) args;

		int status = lua_resume(task->co, NULL, lua_gettop(task->co) > 0 ? lua_gettop(task->co) - 1 : 0);

		if (status != LUA_OK && status != LUA_YIELD){

			LOG( "ERROR", lua_tostring(task->co, -1));

			core_break(task->loop, EVBREAK_ALL);

		}
		xfree(task);
	}
}

int
task_start(lua_State *L){

    lua_State *co = lua_tothread(L, 1);
    if (!co) return 0;

	core_task* task = xrealloc(NULL, sizeof(core_task));

	task->co = co;

	task->loop = core_default_loop();

	core_once(task->loop, (void*)task, TASK_CB);

    return 1;
}


LUAMOD_API int
luaopen_task(lua_State *L){

	luaL_checkversion(L);

	luaL_Reg task_libs[] = {
		{"spwan", task_start},
		{NULL, NULL}
	};
	luaL_newlib(L, task_libs);
	return 1;
}
