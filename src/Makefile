.PHONY : build

default :
	@echo "======================================="
	@echo "Please use 'make build' command to build it.."
	@echo "======================================="

core_tcp.o :
	$(CC) -c core_tcp.c

core_loop.o :
	$(CC) -c core_loop.c

core_udp.o :
	$(CC) -c core_udp.c

core_signal.o :
	$(CC) -c core_signal.c

core_timer.o :
	$(CC) -c core_timer.c

CC = cc

CORE_OBJ += core_signal.o core_tcp.o core_loop.o core_udp.o core_timer.o

LIBS += -L/usr/local/lib

INCLUDES += -I/usr/local/include

CFLAGS += -DJEMALLOC

DLL += -lev -ljemalloc -llua

MACRO += -Wunused-value

build : $(CORE_OBJ)

	$(CC) $(CORE_OBJ) -o core_event.so $(INCLUDES) $(LIBS) $(MACRO) $(CFLAGS) $(DLL) -fPIC --shared -O2

	$(CC) core_event.so core_start.c -o main $(MACRO) $(DLL) -O2

clean :
	rm -rf *.o *.so