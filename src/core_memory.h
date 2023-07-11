#ifndef __CORE_MEMORY__
#define __CORE_MEMORY__

#include <stdlib.h>

#define malloc  xmalloc
#define calloc  xcalloc
#define realloc xrealloc
#define free    xfree

#define strdup   xstrdup
#define strndup  xstrndup
#define realpath xrealpath

char* xstrdup(const char *s);
char* xstrndup(const char *s, size_t n);
char* xrealpath(const char *path, char *resolved);

void* xmalloc(size_t size);
void* xcalloc(size_t nmemb, size_t size);
void* xrealloc(void* ptr, size_t size); 
void  xfree(void *ptr);

#endif
