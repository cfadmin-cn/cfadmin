#ifndef __CORE_H__
#define __CORE_H__

#ifdef __cplusplus
	extern "C" {
#endif

#ifndef _GNU_SOURCE
	#define _GNU_SOURCE
#endif

#include "core_sys.h"
#include "core_memory.h"
#include "core_ev.h"

#ifdef __cplusplus
	}
#endif
static inline void core_exit() {
	return _exit(EXIT_FAILURE);
}

#endif
