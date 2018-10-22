#include "core_ev.h"
#include "core_memory.h"

void
once_cb(struct ev_once *once, int revents){
	/* 用户回调函数 */
	once->cb(once, once->data, revents);
	if (once->timer){
		ev_timer_stop(EV_DEFAULT_ once->timer);
		free(once->timer);
	}
	if (once->io){
		ev_io_stop(EV_DEFAULT_ once->io);
		free(once->io);
	}
	free(once);
}

void
once_timer_cb(EV_P_ ev_timer *timer, int revents){
	struct ev_once *once = (struct ev_once *)ev_get_watcher_userdata(timer);
	if (once)
		once_cb(once, revents);
}

void
once_io_cb(EV_P_ ev_io *io, int revents){
	struct ev_once *once = (struct ev_once *)ev_get_watcher_userdata(io);
	if (once)
		once_cb(once, revents);
}


void
ev_once(int socket, int events, ev_tstamp timeout, void (*cb)(EV_ONCE_ void *arg, int revents), void *args) {
	struct ev_once *once = calloc(1, sizeof(struct ev_once));
	if (!once) return ;
	once->cb = cb;
	if (args) once->data = args;

	/* 是否需要监听socket */
	if (socket > 0){
		once->io = realloc(0, sizeof(ev_io));
		if(once->io){
			ev_set_watcher_userdata(once->io, once);
			ev_io_init(once->io, once_io_cb, socket, events);
			ev_io_start(EV_DEFAULT_ once->io);
		}
	}
	/* 是否需要启动定时器 */
	if (timeout >= 0.){
		once->timer = realloc(0, sizeof(ev_timer));
		if(once->timer){
			ev_set_watcher_userdata(once->timer, once);
			ev_timer_init(once->timer, once_timer_cb, timeout, 0);
			ev_timer_start(EV_DEFAULT_ once->timer);
		}
	}
}
