#include "core.h"

void
write_pid(const char *filename) {
  errno = 0;
  FILE *f = fopen(filename, "w");
  if (!f) {
    LOG("ERROR", strerror(errno));
    return exit(-1);
  }
  fprintf(f, "%d\n", getpid());
  fclose(f);
}

int
main(int argc, char const *argv[])
{
// #if !defined(__APPLE__)
  /* 后台运行 */
  if (argc > 1 && 0 == strcmp("-d", argv[argc-1])) daemon(1, 0);
// #endif

  /* 建立Pid文件 */
  write_pid("cfadmin.pid");

  /* 系统初始化 */
  core_sys_init();

  /* 运行事件循环 */
  core_sys_run();

  return 0;
}
