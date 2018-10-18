#ifndef __CORE_COROUTINE__
#define __CORE_COROUTINE__

#include "core_sys.h"
#include "core_memory.h"
#include "core_ev.h"


#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

/* 客户端 or 服务端 */
#define IS_CLIENT 1
#define IS_SERVER 1

/* 内置库注入函数 */
void lua_openlibs(lua_State *L);

#endif