#include "core_memory.h"

void* xmalloc(size_t size){
  return malloc(size);
}

void* xcalloc(size_t nmemb, size_t size){
  return calloc(nmemb, size);
}


void* xrealloc(void* ptr, size_t size){
  return realloc(ptr, size);
}


void xfree(void *ptr){
  return free(ptr);
}