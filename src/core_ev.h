#ifndef __CORE_EV__
#define __CORE_EV__

/* 关闭3.x版本兼容选择特性 */
#define EV_COMPAT3 0

/* 关闭事件循环验证 */
#define EV_VERIFY 0

/* 使用Math库的Floor方法计算 */
#define EV_USE_FLOOR 1

#define EV_FORK_ENABLE 0
#define EV_CHILD_ENABLE 0
#define EV_CHECK_ENABLE 0
#define EV_EMBED_ENABLE 0
#define EV_PREPARE_ENABLE 0
#define EV_PREPARE_ENABLE 0

/* 使用四叉堆结构 */
#define EV_USE_4HEAP 1
#define EV_HEAP_CACHE_AT 1

/* 单线程模型 */
#define EV_NO_SMP 1
#define EV_NO_THREADS 1

#if defined(linux) || defined(__linux__) || defined(__MSYS__)
	#if defined(__MSYS__)
		#define EV_USE_SELECT 1
	#else
		#define EV_USE_EPOLL 1
		#define EV_USE_INOTIFY 1
		#define EV_USE_EVENTFD 1
	#endif
	#define EV_USE_SIGNALFD 1
	#define EV_USE_TIMERFD 1
#elif defined(__APPLE__) || defined(__OpenBSD__) || defined(__NetBSD__) || defined(__FreeBSD__) || defined(__DragonFly__)
	#define EV_USE_KQUEUE 1
#else
	#define EV_USE_SELECT 1
#endif

#include "ev.h"

#define CORE_LOOP  core_default_loop()

#define CORE_LOOP_ CORE_LOOP,

#define CORE_P core_loop *loop

#define CORE_P_ core_loop *loop,

/* 获取用户数据 */
#define core_get_watcher_userdata(watcher) ((watcher)->data ? (watcher)->data: NULL)

/* 设置用户数据 */
#define core_set_watcher_userdata(watcher, userdata) ((watcher)->data = (userdata))

void core_ev_set_allocator (void *(*cb)(void *ptr, long size));

void core_ev_set_syserr_cb (void (*cb)(const char *msg));

typedef ev_io core_io;
typedef ev_idle core_task;
typedef ev_timer core_timer;
typedef ev_signal core_signal;
typedef struct ev_loop core_loop;

typedef void (*_IO_CB)(core_loop *loop, core_io *io, int revents);
typedef void (*_TASK_CB)(core_loop *loop, core_task *task, int revents);
typedef void (*_TIMER_CB)(core_loop *loop, core_timer *timer, int revents);
typedef void (*_SIGNAL_CB)(core_loop *loop, core_signal *signal, int revents);

/* ===========  Timer  =========== */
void core_timer_init(core_timer *timer, _TIMER_CB cb);

void core_timer_start(core_loop *loop, core_timer *timer, ev_tstamp timeout);

void core_timer_stop(core_loop *loop, core_timer *timer);
/* ===========  Timer  =========== */

/* ===========  IO  =========== */
void core_io_init(core_io *io, _IO_CB cb, int fd, int events);

void core_io_start(core_loop *loop, core_io *io);

void core_io_stop(core_loop *loop, core_io *io);
/* ===========  IO  =========== */

/* ===========  TASK  =========== */
void core_task_init(core_task *task, _TASK_CB cb);

void core_task_start(core_loop *loop, core_task *task);

void core_task_stop(core_loop *loop, core_task *task);
/* ===========  TASK  =========== */

/* ===========  Signal  =========== */
void core_signal_init(core_signal *signal, _SIGNAL_CB cb, int signum);

void core_signal_start(core_loop *loop, core_signal *signal);
/* ===========  Signal  =========== */

void core_break(core_loop *loop, int mode);

int core_start(core_loop *loop, int mode);

core_loop* core_loop_fork(core_loop* loop);

core_loop* core_default_loop();

#endif
