#ifndef __CORE_MEMORY__
#define __CORE_MEMORY__

#if defined(JEMALLOC)
	#include "jemalloc/jemalloc.h"
#elif defined(TCMALLOC)
	#include "gperftools/tcmalloc.h"
	#define malloc  tc_malloc
	#define calloc  tc_calloc
	#define realloc tc_realloc
	#define free 	tc_free
	void exit(int status);
	void _exit(int status);
	int atoi(const char *nptr);
	char * getenv(const char* name);
	int unsetenv(const char* name);
	int setenv(const char* name, const char* value, int overwrite);
#else
	#include <stdlib.h>
#endif


void* xmalloc (size_t size);

void* xcalloc (size_t nmemb, size_t size);

void* xrealloc(void* ptr, size_t size); 

void xfree(void *ptr);

#endif