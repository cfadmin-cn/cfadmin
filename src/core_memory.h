#ifndef __CORE_MEMORY__
#define __CORE_MEMORY__

#if JEMALLOC
	#include "jemalloc/jemalloc.h"
#elif TCMALLOC
	#include "gperftools/tcmalloc.h"
	#define malloc  tc_malloc
	#define calloc  tc_calloc
	#define realloc tc_realloc
	#define free 	tc_free
#else
	#include <stdlib.h>
#endif


void *xmalloc (size_t size);

void *xcalloc (size_t nmemb, size_t size);

void *xrealloc(void* ptr, size_t size); 

void xfree(void *ptr);

#endif