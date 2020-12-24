#ifndef __CORE_H__
#define __CORE_H__

#include "core_sys.h"
#include "core_memory.h"
#include "core_ev.h"

int core_run(const char entry[], int workers);

#endif
