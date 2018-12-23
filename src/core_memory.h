#ifndef __CORE_MEMORY__
#define __CORE_MEMORY__

#ifdef JEMALLOC
	#include "jemalloc/jemalloc.h"
#else
	#include <stdlib.h>
#endif


void *xmalloc (size_t size);

void *xcalloc (size_t nmemb, size_t size);

void *xrealloc(void* ptr, size_t size); 

void xfree(void *ptr);

#endif