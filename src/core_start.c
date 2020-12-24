#include "core.h"

#define __CFADMIN_VERSION__ "1.0"

#define MAX_ENTRY_LENGTH (1 << 10)

static char script_entry[MAX_ENTRY_LENGTH] = "script/main.lua";

static char pid_filename[MAX_ENTRY_LENGTH] = "cfadmin.pid";

static int workers = 1;

/* 打印使用指南 */
void usage_print() {
  printf("cfadmin System  : %s(%s)\n", __OS__, __VERSION__ );
  printf("\n");
  printf("cfadmin Version : %s\n", __CFADMIN_VERSION__ );
  printf("\n");
  printf(
    "cfadmin Usage: ./cfadmin [options]\n" \
    "\n" \
    "      -h <None>          \"Print `cfadmin` usage.\"\n" \
    "\n" \
    "      -d <None>          \"Make `cfadmin` run in daemon mode.\"\n" \
    "\n" \
    "      -e <FILENAME>      \"Specify `lua` entry file name.\"\n" \
    "\n" \
    "      -p <FILENAME>      \"Specify the process `Pid` write file name.\"\n" \
    "\n" \
    "      -k <Pid | File>    \"Send `SIGKILL` signal to `Pid` or `Pid File`.\"\n" \
    "\n" \
  );
}

/* 建立Pid文件 */
void write_pid_file(const char *filename) {
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

/* 指定入口文件路径 */
void specify_entry_file(const char *filename) {
  memset(script_entry, 0x0, MAX_ENTRY_LENGTH);
  memmove(script_entry, filename, strlen(filename));
}

/* 指定pid文件路径 */
void specify_pid_file(const char *filename) {
  memset(pid_filename, 0x0, MAX_ENTRY_LENGTH);
  memmove(pid_filename, filename, strlen(filename));
}

/* 给指定`PID`或包含`PID`的文件发送`SIGQUIT`信号 */
void specify_kill_process(const char *spid) {
  int pid = atoi(spid);
  if (pid <= 1) {
    FILE *fp = fopen(spid, "rb");
    if (!fp) {
      LOG("ERROR", "Invalid Pid or pid file name.");
      return;
    }
    char pbuf[20];
    memset(pbuf, 0x0, 20);
    fread(pbuf, 1, 20, fp);
    fclose(fp);
    pid = atoi(pbuf);
    if (pid <= 1){
      LOG("ERROR", "Invalid Pid or File name.");
      return;
    }
  }
  kill(pid, SIGQUIT);
}

void specify_workers(const char* w) {
  workers = atoi(w);
  if (workers <= 0 )
    workers = 1;
}

/* 后台运行 */
void specify_process_daemon() {
  daemon(1, 0);
}

void check_args(int argc, char const *argv[]) {
  int opt = -1;
  int opterr = 0;
  while ((opt = getopt(argc, (char *const *)argv, "hde:p:k:w:")) != -1) {
    switch(opt) {
      case 'w':
        specify_workers(optarg);
        continue;
      case 'e':
        specify_entry_file(optarg);
        continue;
      case 'p':
        specify_pid_file(optarg);
        continue;
      case 'k':
        specify_kill_process(optarg);
        return _exit(0);
      case 'd':
        specify_process_daemon();
        continue;
      case '?':
      case 'h':
      default :
        usage_print();
        exit(0);
    }
  }

  write_pid_file(pid_filename);
  return;
}

int main(int argc, char const *argv[])
{

  /* 参数检查 */
  check_args(argc, argv);

  /* 初始化 */ 
  return core_run(script_entry, workers);
}
