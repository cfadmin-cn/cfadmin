#ifndef __CORE_H__
#define __CORE_H__

#include "core_sys.h"
#include "core_memory.h"
#include "core_ev.h"

#include <openssl/ssl.h>
#include <openssl/err.h>

SSL_CTX *ctx = NULL;

#define CORE_LOOP  ev_default_loop(ev_supported_backends() & EVBACKEND_EPOLL || ev_supported_backends() & EVBACKEND_KQUEUE)

#define CORE_LOOP_ CORE_LOOP,

#define CORE_P core_loop *loop

#define CORE_P_ core_loop *loop,

/* 获取用户数据 */
#define core_get_watcher_userdata(watcher) ((watcher)->data ? (watcher)->data: NULL)

/* 设置用户数据 */
#define core_set_watcher_userdata(watcher, userdata) ((watcher)->data = (userdata))


typedef ev_io core_io;
typedef ev_timer core_timer;
typedef struct ev_loop core_loop;

typedef void (*IO_CB)(core_loop *loop, core_io *io, int revents);
typedef void (*TIMER_CB)(core_loop *loop, core_timer *timer, int revents);


/* ===========  Timer  =========== */
void core_timer_init(core_timer *timer, TIMER_CB cb);

void core_timer_start(core_loop *loop, core_timer *timer, ev_tstamp timeout);

void core_timer_stop(core_loop *loop, core_timer *timer);
/* ===========  Timer  =========== */

/* ===========  IO  =========== */
void core_io_init(core_io *io, IO_CB cb, int fd, int events);

void core_io_start(core_loop *loop, core_io *io);

void core_io_stop(core_loop *loop, core_io *io);
/* ===========  IO  =========== */

void core_break(core_loop *loop, int mode);

int core_start(core_loop *loop, int mode);

core_loop* core_default_loop(int flags);


void core_sys_init();

int core_sys_run();

#endif