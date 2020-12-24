.PHONY : build rebuild clean

default :
	@echo "======================================="
	@echo "Please use 'make build' command to build it.."
	@echo "Please use 'make rebuild' command to build it.."
	@echo "Please use 'make clean' command to clean all."
	@echo "======================================="

CC = cc
INCLUDES += -I../../../src -I/usr/local/include
LIBS = -L../ -L../../ -L../../../ -L/usr/local/lib
CFLAGS = -O3 -shared -fPIC
DLL = -lcore -llua

build:
	@$(CC) -o lpeg.so lpcap.c lpcode.c lpprint.c lptree.c lpvm.c $(CFLAGS) $(INCLUDES) $(LIBS) $(DLL)
	@mv *.so ../../
