#ifndef __CORE_H__
#define __CORE_H__

#include "core_sys.h"
#include "core_memory.h"
#include "core_ev.h"

// 用来退出父子进程
static inline void core_exit() {
	if (getppid() > 0)
		kill(0, SIGKILL);
	return _exit(EXIT_FAILURE);
}

#endif
