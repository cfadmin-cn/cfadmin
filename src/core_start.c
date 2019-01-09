#include "core.h"

int
main(int argc, char const *argv[])
{
    /* 后台运行 */
    // daemon(0, 0);

	/* 系统初始化 */
	core_sys_init();
    /* 运行事件循环 */
	core_sys_run();

	return 0;
}
