.PHONY : build rebuild clean

default :
	@echo "======================================="
	@echo "Please use 'make build' command to build it.."
	@echo "Please use 'make rebuild' command to build it.."
	@echo "Please use 'make clean' command to clean all."
	@echo "======================================="

CC = cc

INCLUDES += -I../../../src -I/usr/local/include
LIBS = -L../ -L../../../ -L/usr/local/lib

CFLAGS = -O3 -Wall -shared -fPIC
DLL = -lcore -llua

build:
	$(CC) -o lprotobuf.so lpb.c $(INCLUDES) $(LIBS) $(CFLAGS) $(DLL)
	mv *.so ../../

rebuild:
	$(CC) -o lprotobuf.so lpb.c $(INCLUDES) $(LIBS) $(CFLAGS) $(DLL)
	mv *.so ../../

clean:
	rm -rf *.o *.so
