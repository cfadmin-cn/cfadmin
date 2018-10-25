#include "stdio.h"
#include "stdlib.h"

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"


int main(int argc, char const *argv[])
{
	lua_State *L = luaL_newstate();
	if (!L) return -1;
	luaL_openlibs(L);

	int status = luaL_loadstring(L, "function test(...) print('哈哈') end return coroutine.create(test)");
	if (status != LUA_OK){
		printf("error:%s\n", lua_tostring(L, -1));
		return -1;
	}
	int ret = lua_resume(L, NULL, 0);
	if (ret > 1){
		printf("error:%s\n", lua_tostring(L, -1));
		return -1;
	}
	lua_State *co = lua_tothread(L, 1);
	ret = lua_resume(co, NULL, 0);
	if (ret > 1){
		printf("error:%s\n", lua_tostring(L, -1));
		return -1;
	}
	return 0;
}