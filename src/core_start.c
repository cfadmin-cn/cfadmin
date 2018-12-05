#include "core.h"

int
main(int argc, char const *argv[])
{
	/* 系统初始化 */
	core_sys_init();

	core_sys_run();

	return 0;
}
