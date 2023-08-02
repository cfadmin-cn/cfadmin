#ifndef __CORE_MEMORY__
#define __CORE_MEMORY__

#include <stdlib.h>

#define malloc  xmalloc
#define calloc  xcalloc
#define realloc xrealloc
#define free    xfree

#define xmalloc  xmalloc
#define xcalloc  xcalloc
#define xrealloc xrealloc
#define xfree    xfree

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

#ifdef __cplusplus
  #if defined(__llvm__) || defined(__clang__)
    #pragma GCC diagnostic ignored "-Winline-new-delete"
  #endif
  #include <new>
  /* malloc */
  inline void* operator new(std::size_t size) noexcept(false) { return xmalloc(size); }
  inline void* operator new[](std::size_t size) noexcept(false) { return xmalloc(size); }
  /* free */
  inline void operator delete(void *ptr) noexcept { xfree(ptr); }
  inline void operator delete[](void *ptr) noexcept { xfree(ptr); }
#endif

#endif
