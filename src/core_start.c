#include "core.h"

#define MAX_ENTRY_LENGTH (1 << 8)

static char script_entry[MAX_ENTRY_LENGTH] = "script/main.lua";

void write_pid(const char *filename) {
  errno = 0;
  FILE *f = fopen(filename, "w");
  if (!f) {
    LOG("ERROR", strerror(errno));
    return exit(-1);
  }
  fprintf(f, "%d\n", getpid());
  fflush(f);
  fclose(f);
}

void check_args(int argc, char const *argv[]) {
  if (argc > 1) {
    for (uint32_t index = 0; index < argc; index ++) {
      if (!strcmp("-d", argv[index])){
        daemon(1, 0);
        continue;
      }
      if (!strcmp("-e", argv[index])) {
        if (argc > index){
          memset(script_entry, 0x0, MAX_ENTRY_LENGTH);
          memmove(script_entry, argv[index + 1], strlen(argv[index + 1]));
        }
        continue;
      }

    }
  }
}

int main(int argc, char const *argv[])
{

  check_args(argc, argv);

  /* 建立Pid文件 */
  write_pid("cfadmin.pid");

  /* 系统初始化 */
  core_sys_init(script_entry);

  /* 运行事件循环 */
  core_sys_run();

  return 0;
}
