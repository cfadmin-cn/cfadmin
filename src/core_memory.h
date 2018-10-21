#ifndef __CORE_MEMORY__
#define __CORE_MEMORY__

#ifdef JEMALLOC
	#include "jemalloc/jemalloc.h"
	#define malloc je_malloc
	#define calloc je_calloc
	#define realloc je_realloc
	#define free je_free
#else
	#include <stdlib.h>
#endif

#endif