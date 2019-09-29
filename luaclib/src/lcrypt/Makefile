.PHONY : build rebuild clean

default :
	@echo "======================================="
	@echo "Please use 'make build' command to build it.."
	@echo "Please use 'make rebuild' command to build it.."
	@echo "Please use 'make clean' command to clean all."
	@echo "======================================="

CC = cc

CFLAGS = -O3 -Wall -shared -fPIC -fno-strict-aliasing
DLL = -lcore -llua

INCLUDES = -I../../../ -I/usr/local/include
LIBS = -L../ -L../../../ -L/usr/local/lib

build:
	@$(CC) -o lcrypt.so lcrypt.c crc.c md5.c url.c sha1.c sha2.c $(INCLUDES) $(LIBS) $(CFLAGS) $(DLL)
	@mv *.so ../../
