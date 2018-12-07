.PHONY : build rebuild clean

default :
	@echo "======================================="
	@echo "Please use 'make build' command to build it.."
	@echo "Please use 'make clean' command to clean all."
	@echo "======================================="

CFLAGS = -Wall -O2 -std=c99
CC = cc

INCLUDE = -I/usr/local/include
LIB = -L/usr/local/lib

lpcap.o: lpcap.c lpcap.h lptypes.h
lpcode.o: lpcode.c lptypes.h lpcode.h lptree.h lpvm.h lpcap.h
lpprint.o: lpprint.c lptypes.h lpprint.h lptree.h lpvm.h lpcap.h
lptree.o: lptree.c lptypes.h lpcap.h lpcode.h lptree.h lpvm.h lpprint.h
lpvm.o: lpvm.c lpcap.h lptypes.h lpvm.h lpprint.h lptree.h

OBJS = lpvm.o lpcap.o lptree.o lpcode.o lpprint.o

build: $(OBJS)
	$(CC) -o lpeg.so $(OBJS) $(CFLAGS) $(INCLUDE) $(LIB) --shared -fPIC ../../../core.so

rebuild : $(OBJS)
	$(CC) -o lpeg.so $(OBJS) $(CFLAGS) $(INCLUDE) $(LIB) --shared -fPIC ../../../core.so
	rm -rf *.o
	mv lpeg.so ../../

clean:
	rm -rf *.o *.so
