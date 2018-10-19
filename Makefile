.PHONY : default debug build clean

default :
	@echo "======================================="
	@echo "Please use 'make' command to build it.."
	@echo "Please use 'make' command to build it.."
	@echo "======================================="


objects = core_start.o core_ev.o core_signal.o core_coroutine.o

core_start.o : core.h
	cc -c core_start.c

core_ev.o :
	cc -c core_ev.c

core_signal.o : core_signal.h
	cc -c core_signal.c

core_coroutine.o : core_coroutine.h
	cc -c core_coroutine.c

LIB += -L/usr/local/lib

INCLUDE += -I/usr/local/include


debug : $(objects)
	cc -o main $(objects) $(INCLUDE) $(LIB) -Wall -Wl -lev -ljemalloc -llua -O0 -ggdb

build : $(objects)
	cc -o main $(objects) $(INCLUDE) $(LIB) -Wall -Wl -lev -ljemalloc -llua -O2

clean :
	rm -rf *.o *.dSYM main