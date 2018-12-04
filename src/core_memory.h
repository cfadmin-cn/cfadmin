#ifndef __CORE_MEMORY__
#define __CORE_MEMORY__

#ifdef JEMALLOC
    #warning "used jemalloc"
	#include "jemalloc/jemalloc.h"
	#define xmalloc je_malloc
	#define xcalloc je_calloc
	#define xrealloc je_realloc
	#define xfree je_free
#else
	#include <stdlib.h>
    #define xmalloc malloc
    #define xcalloc calloc
    #define xrealloc realloc
    #define xfree free
#endif

#endif