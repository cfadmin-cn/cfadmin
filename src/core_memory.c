#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#if defined(TCMALLOC) || defined(USE_TCMALLOC)
  #include <gperftools/tcmalloc.h>
  #define _malloc   tc_malloc
  #define _calloc   tc_calloc
  #define _realloc  tc_realloc
  #define _free     tc_free
#elif defined(JEMALLOC) || defined(USE_JEMALLOC)
  #include <jemalloc/jemalloc.h>
  #define _malloc   je_malloc
  #define _calloc   je_calloc
  #define _realloc  je_realloc
  #define _free     je_free
#elif defined(MIMALLOC) || defined(USE_MIMALLOC)
  #include <mimalloc.h>
  #define _malloc   mi_malloc
  #define _calloc   mi_calloc
  #define _realloc  mi_realloc
  #define _free     mi_free
#else
  #define _malloc   malloc
  #define _calloc   calloc
  #define _realloc  realloc
  #define _free     free
#endif

void* xmalloc(size_t size){
  return _malloc(size);
}

void* xcalloc(size_t nmemb, size_t size){
  return _calloc(nmemb, size);
}

void* xrealloc(void* ptr, size_t size){
  return _realloc(ptr, size);
}

void xfree(void *ptr){
  return _free(ptr);
}

char* xstrdup(const char *s) {
  if (!s)
    return NULL;
  size_t n = strlen(s);
  char* p = _malloc(n + 1);
  if (!p)
    return NULL;
  memcpy(p, s, n);
  p[n] = '\x00';
  return p;
}
char* xstrndup(const char *s, size_t n) {
  if (!s)
    return NULL;
  char* p = _malloc(n + 1);
  if (!p)
    return NULL;
  memcpy(p, s, n);
  p[n] = '\x00';
  return p;
}

char* xrealpath(const char *path, char *resolved) {
  if (!path)
    return NULL;
  if (!resolved)
    resolved = _calloc(1, sysconf(_PC_PATH_MAX));
  return realpath(path, resolved);
}