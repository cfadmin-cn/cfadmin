#include "core_ev.h"

/* ===========  Timer  =========== */
void
core_timer_init(core_timer *timer, _TIMER_CB cb){

	timer->repeat = timer->at = 0x0;

	ev_init(timer, cb);

}

void
core_timer_start(core_loop *loop, core_timer *timer, ev_tstamp timeout){

	timer->repeat = timeout;

	ev_timer_again(loop ? loop : CORE_LOOP, timer);

}

void
core_timer_stop(core_loop *loop, core_timer *timer){

	timer->repeat = timer->at = 0x0;

	ev_timer_again(loop ? loop : CORE_LOOP, timer);

}
/* ===========  Timer  =========== */




/* ===========  IO  =========== */
void
core_io_init(core_io *io, _IO_CB cb, int fd, int events){

	ev_io_init(io, cb, fd, events);

}

void
core_io_start(core_loop *loop, core_io *io){

	ev_io_start(loop ? loop : CORE_LOOP, io);

}

void
core_io_stop(core_loop *loop, core_io *io){

	if (io->events || io->fd){

		ev_io_stop(loop ? loop : CORE_LOOP, io);

		io->fd = io->events = 0x0;

	}

}
/* ===========  IO  =========== */


/* ===========  TASK  =========== */

void
core_task_init(core_task *task, _TASK_CB cb){

	ev_idle_init(task, cb);

}

void
core_task_start(core_loop *loop, core_task *task){

	ev_idle_start(loop ? loop : CORE_LOOP, task);

}

void
core_task_stop(core_loop *loop, core_task *task){

	ev_idle_stop(loop ? loop : CORE_LOOP, task);

}

/* ===========  TASK  =========== */


core_loop *
core_default_loop(){
	// 	ev_supported_backends() & EVBACKEND_EPOLL  || // Linux   使用 epoll
	// 	ev_supported_backends() & EVBACKEND_KQUEUE || // mac|BSD 使用 kqueue
	// 	ev_supported_backends() & EVBACKEND_SELECT || // other   使用 select
	// 	EVFLAG_AUTO								  	  // select  都没有就自动选择
	return ev_default_loop(ev_embeddable_backends() & ev_supported_backends() || EVFLAG_AUTO);
}

void
core_break(core_loop *loop, int mode){
	return ev_break(loop ? loop : CORE_LOOP, mode);
}

void
core_ev_set_allocator(void *(*cb)(void *ptr, long size)){
	return ev_set_allocator(cb);
}

void
core_ev_set_syserr_cb(void (*cb)(const char *msg)){
	return ev_set_syserr_cb(cb);
}

int
core_start(core_loop *loop, int mode){

	return ev_run(loop ? loop : CORE_LOOP, mode);

}
