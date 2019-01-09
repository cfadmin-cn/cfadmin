#ifndef __CORE_H__
#define __CORE_H__

#include "core_sys.h"
#include "core_memory.h"
#include "core_ev.h"

#define CORE_LOOP  core_default_loop()

#define CORE_LOOP_ CORE_LOOP,

#define CORE_P core_loop *loop

#define CORE_P_ core_loop *loop,

/* 获取用户数据 */
#define core_get_watcher_userdata(watcher) ((watcher)->data ? (watcher)->data: NULL)

/* 设置用户数据 */
#define core_set_watcher_userdata(watcher, userdata) ((watcher)->data = (userdata))


typedef ev_io core_io;
typedef ev_idle core_task;
typedef ev_timer core_timer;
typedef ev_signal core_signal;
typedef struct ev_loop core_loop;

typedef void (*_IO_CB)(core_loop *loop, core_io *io, int revents);
typedef void (*_TASK_CB)(core_loop *loop, core_task *task, int revents);
typedef void (*_TIMER_CB)(core_loop *loop, core_timer *timer, int revents);

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


void core_break(core_loop *loop, int mode);

int core_start(core_loop *loop, int mode);

core_loop* core_default_loop();


void core_sys_init();

int core_sys_run();

#endif
