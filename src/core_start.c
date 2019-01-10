#include "core.h"

int
main(int argc, char const *argv[])
{
#if !defined(__APPLE__)
    /* 后台运行 */
	if (argc == 1 && strcmp("", argv[argc-1])) daemon(0, 0);
#endif
	/* 系统初始化 */
	core_sys_init();
    /* 运行事件循环 */
	core_sys_run();

	return 0;
}
