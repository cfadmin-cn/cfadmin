#include "core.h"

int core_worker_run(const char entry[]);

int core_master_run(pid_t *pids, int* pidcount);

enum {
  isMaster = 1,
  isWorker = 2,
};

#define __CFADMIN_VERSION__ "1.0"

#define MAX_FILENAME_LEN (1 << 10)

static char script_entry[MAX_FILENAME_LEN] = "script/main.lua";

static char pid_filename[MAX_FILENAME_LEN] = "cfadmin.pid";

static int nprocess = 1;

static int daemoned = 0;

static int pmode = 0;

#define MasterPrefix ("cfadmin - Manager Process :")
#define WorkerPrefix ("cfadmin - Worker Process")

/* 打印使用指南 */
void cfadmin_usage_print() {
  printf("cfadmin System  : %s(%s)\n", __OS__, __VERSION__ );
  printf("\n");
  printf("cfadmin Version : %s\n", __CFADMIN_VERSION__ );
  printf("\n");
  printf(
    "cfadmin Usage: ./cfadmin [options]\n" \
    "\n" \
    "    -h <None>           \"Print `cfadmin` usage.\"\n" \
    "\n" \
    "    -d <None>           \"Make `cfadmin` run in daemon mode.\"\n" \
    "\n" \
    "    -e <FILENAME>       \"Specified `lua` entry file name.\"\n" \
    "\n" \
    "    -p <FILENAME>       \"Specified the process `Pid` write file name.\"\n" \
    "\n" \
    "    -k <Pid | File>     \"Send `SIGKILL` signal to `Pid` or `Pid File`.\"\n" \
    "\n" \
    "    -w <number Process> \"Spawn specified number of worker processes.\"\n" \
    "\n" \
  );
  exit(0);
}

/* 指定入口文件路径 */
static inline void cfadmin_specify_entry_file(const char *filename) {
  memset(script_entry, 0x0, MAX_FILENAME_LEN);
  memmove(script_entry, filename, strlen(filename));
}

/* 指定pid文件路径 */
static inline void cfadmin_specify_pid_file(const char *filename) {
  memset(pid_filename, 0x0, MAX_FILENAME_LEN);
  memmove(pid_filename, filename, strlen(filename));
}

/* 给指定`PID`或包含`PID`的文件发送`SIGQUIT`信号 */
static inline void cfadmin_specify_kill_process(const char *spid) {
  int pid = atoi(spid);
  if (pid <= 1) {
    FILE *fp = NULL;
    if ((fp = fopen(spid, "rb")) == NULL) {
      LOG("ERROR", "Invalid Pid or pid file name.");
      fclose(fp);
      return;
    }
    char pbuf[20]; memset(pbuf, 0x00, 20);
    if (fread(pbuf, 1, 20, fp) <= 0 || (pid = atoi(pbuf)) <= 1) {
      LOG("ERROR", "Invalid Pid or File name.");
      fclose(fp);
      return;
    }
    fclose(fp);
    remove(pid_filename);
  }
  kill(pid, SIGQUIT);
  exit(0);
}

/* 指定子进程数量 */
static inline void cfadmin_specify_nprocess(const char* w) {
  nprocess = atoi(w);
  if (nprocess <= 0 || nprocess > 255 )
    nprocess = 1;
}

/* 后台运行 */
void cfadmin_specify_process_daemon() {
  daemoned = 1;
}

static inline void cfadmin_init_args(int argc, char const *argv[]) {
  int opt = -1;
  int opterr = 0;
  while ((opt = getopt(argc, (char *const *)argv, "hde:p:k:w:")) != -1) {
    switch(opt) {
      case 'd':
        cfadmin_specify_process_daemon();
        continue;
      case 'w':
        cfadmin_specify_nprocess(optarg);
        continue;
      case 'e':
        cfadmin_specify_entry_file(optarg);
        continue;
      case 'p':
        cfadmin_specify_pid_file(optarg);
        continue;
      case 'k':
        cfadmin_specify_kill_process(optarg);
      case '?':
      case 'h':
      default :
        cfadmin_usage_print();
    }
  }
  return;
}

/* 将主进程ID写入到文件内 */
static inline void cfadmin_write_pid_file(const char *filename, pid_t pid) {
  errno = 0;
  FILE *f = fopen(filename, "w");
  if (!f) {
    LOG("ERROR", strerror(errno));
    return exit(-1);
  }
  fprintf(f, "%d", pid);
  fflush(f);
  fclose(f);
}

/* 设置当前进程运行模式 */
static inline void cfadmin_set_parameters(int mode) {
  if (mode == isMaster){
    unsetenv("cfadmin_isWorker");
    setenv("cfadmin_isMaster", "true", 1);
    setenv("cfadmin_script", script_entry, 1);
    char np[3];
    memset(np, 0x0, 3);
    sprintf(np, "%d", nprocess);
    setenv("cfadmin_nprocess", np, 1);
  } else {
    unsetenv("cfadmin_isMaster");
    setenv("cfadmin_isWorker", "true", 1);
  }
}

/* 初始化参数 */
static inline void cfadmin_unset_parameters() {
  unsetenv("cfadmin_isMaster");
  unsetenv("cfadmin_isWorker");
  unsetenv("cfadmin_nprocess");
  unsetenv("cfadmin_script");
}

/* 多进程 - 运行工作进程 */
static inline int cfadmin_worker_run(const char* entry) {
  return core_worker_run(entry);
}

/* 多进程 - 运行主进程 */
static inline pid_t cfadmin_master_run() {
  /* 获取父进程ID */
  pid_t ppid = getpid();
  /* 所有子进程的PID数组 */
  pid_t npid[nprocess];
  /* 初始化工作进程命令行参数 */
  char *argp[] = { WorkerPrefix, NULL };
  /* 子进程模式 */
  cfadmin_set_parameters(isWorker);
  /* 开始创建进程 */
  int i;
  for (i = 0; i < nprocess; i++){
    int pid = fork();
    if (pid <= 0) {
      if (!pid) {
        /* 启动工作进程 */
        int e = execvp("./cfadmin", (char *const *)argp);
        if (e < 0)
          LOG("ERROR", strerror(errno));
      }
      int index;
      for (index = 0; index < i; index ++)
        kill(npid[index], SIGQUIT);
      kill(ppid, SIGQUIT);
      return (pid_t)-1;
    }
    npid[i] = pid;
  }
  return core_master_run(npid, &nprocess);
}

/* 单进程模式 */
static inline int cfadmin_standalone_run(const char* entry) {
  return cfadmin_worker_run(entry);
}

/* 设置为daemon进程, 并指定`entry`文件与`Pid`文件路径. */
static inline pid_t cfadmin_daemon(int redirect) {

  pid_t pid = fork();
  if (pid != 0)
    exit(EXIT_SUCCESS);

  /* 获取`Pid` */
  pid = getpid();

  /* 设置`SID` */
  setsid();

  /* 打开空设备 */
  int stdin_fd, stdout_fd;

  // 关闭标准输入输出
  if (!redirect) {
    int nfd = open("/dev/null", O_RDWR);
    if (nfd < 0) {
      LOG("ERROR", strerror(errno));
      exit(-1);
    }
    stdin_fd = stdout_fd = nfd;
  } else {
    int rfd = open("/dev/null", O_RDWR);
    if (rfd < 0) {
      LOG("ERROR", strerror(errno));
      exit(-1);
    }
    int wfd = open("logs/cfadmin_stdout.log", O_APPEND);
    if (wfd < 0) {
      LOG("ERROR", strerror(errno));
      exit(-1);
    }
    stdin_fd = rfd;
    stdout_fd = wfd;
  }

  /* 关闭资源 */
  close(STDIN_FILENO);
  close(STDOUT_FILENO);
  close(STDERR_FILENO);
  /* 重定向输入/输出 */
  (void)dup2(stdin_fd, STDIN_FILENO);
  (void)dup2(stdout_fd, STDOUT_FILENO);
  (void)dup2(stdout_fd, STDERR_FILENO);

  return pid;

}

int main(int argc, char const *argv[]) {

  /* 命令行参数初始化 */
  cfadmin_init_args(argc, argv);

#if defined(__MSYS__) || defined(__CYGWIN__)
	/* Windows下不可使用多进程 */
	nprocess = 1;
#else
  int n = -1;
  if (getenv("cfadmin_nprocess"))
    n = atoi(getenv("cfadmin_nprocess"));
  if (n < 255 && n > 0)
    nprocess = n;
#endif

  /* 工作进程执行代码 */
  if(getenv("cfadmin_isWorker") && getenv("cfadmin_script"))
    return cfadmin_worker_run(getenv("cfadmin_script"));

  /* 主进程执行代码 */
  if (getenv("cfadmin_isMaster"))
    return cfadmin_master_run();

  /*
    注意:
      下面为`cfadmin`检查配置的相关代码; 根据配置检查的实际情况决定是否需要使用多进程
      多进程模型目前仅在Linux下可以利用到多核`Accept`, 其他环境仅用多进程来做为`Worker`使用.
  */

  /* 是否需要后台运行 */
  pid_t p = daemoned ? cfadmin_daemon(1) : getpid() ;

  /*将主进程的PID写入到*/
  cfadmin_write_pid_file(pid_filename, p);

  /* 如果是单进程模型, 就无需继续创建父子进程管理. */
  if (nprocess <= 1)
    return cfadmin_standalone_run(script_entry);

  /* 初始化命令行参数 */
  argv[0] = MasterPrefix;

  /* 设置环境变量 */
  cfadmin_set_parameters(isMaster);

  /* 执行代码*/
  int e = execvp("./cfadmin", (char *const *)argv);
  if (e < 0) {
    LOG("ERROR", strerror(errno));
    exit(-1);
  }

  /* 如果失败就删除pid文件*/
  return remove(pid_filename);

}