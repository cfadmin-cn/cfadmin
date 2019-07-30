.PHONY : build rebuild clean

default :
	@echo "======================================="
	@echo "Please use 'make build' command to build it.."
	@echo "Please use 'make rebuild' command to build it.."
	@echo "Please use 'make clean' command to clean all."
	@echo "======================================="

CC = cc

INCLUDE = -I/usr/local/include
LIB = -L/usr/local/lib -L../ -L../../../

CFLAGS = -O3 -Wall -shared -fPIC -Wno-unused-function -fno-strict-aliasing -Wno-uninitialized
DLL = -lcore

build:
	$(CC) -o lffi.so ffi.c parser.c ctype.c $(INCLUDE) $(LIB) $(CFLAGS) $(DLL)
	mv *.so ../../

rebuild:
	$(CC) -o lffi.so ffi.c parser.c ctype.c $(INCLUDE) $(LIB) $(CFLAGS) $(DLL)
	mv *.so ../../

clean:
	rm -rf *.o *.so
