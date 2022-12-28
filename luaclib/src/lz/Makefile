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

CFLAGS = -O3 -Wall -shared -fPIC -Wl,-rpath,. -Wl,-rpath,.. -Wl,-rpath,/usr/local/lib

# 是用内置库
# MICRO =
# DLL = -lcore
# 使用`zlib`
MICRO = -DUSE_ZLIB=1
DLL = -lcore -lz

build:
	@$(CC) -o lz.so lzlib.c miniz.c $(INCLUDES) $(LIBS) $(CFLAGS) $(DLL) $(MICRO)
	@mv *.so ../../
