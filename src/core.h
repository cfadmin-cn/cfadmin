#ifndef __CORE_H__
#define __CORE_H__

#include "core_sys.h"
#include "core_memory.h"
#include "core_ev.h"

static inline void core_exit() {
	return _exit(EXIT_FAILURE);
}

#endif
