.PHONY : build

default :
	@echo "======================================="
	@echo "Please use 'make build' command to build it.."
	@echo "======================================="
	
core_ev.o :
	$(CC) -c core_ev.c

core_socket.o :
	$(CC) -c core_socket.c

core_signal.o :
	$(CC) -c core_signal.c

core_timer.o :
	$(CC) -c core_timer.c

CC = cc

CORE_OBJ += core_signal.o core_ev.o core_socket.o core_timer.o

LIBS += -L/usr/local/lib

INCLUDES += -I/usr/local/include

CFLAGS += -DJEMALLOC

DLL += -lev -ljemalloc -llua

build : $(CORE_OBJ)

	$(CC) $(CORE_OBJ) -o core_event.so $(INCLUDES) $(LIBS) $(CFLAGS) $(DLL) -fPIC --shared -Wall -O2

	$(CC) core_event.so core_start.c -o main $(INCLUDES) $(LIBS) $(CFLAGS) $(DLL) -Wall -O2

clean :
	rm -rf *.o *.so