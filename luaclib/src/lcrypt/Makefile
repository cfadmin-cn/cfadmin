.PHONY : build rebuild clean

default :
	@echo "======================================="
	@echo "Please use 'make build' command to build it.."
	@echo "Please use 'make rebuild' command to build it.."
	@echo "Please use 'make clean' command to clean all."
	@echo "======================================="

CC = cc

CFLAGS = -O3 -w -shared -fPIC -DNDEBUG

DLL = -lcore

INCLUDE = -I/usr/local/include
LIB = -L/usr/local/lib -L../ -L../../../

build:
	$(CC) -o lcrypt.so lcrypt.c crc.c sha1.c sha256.c $(INCLUDE) $(LIB) $(CFLAGS) $(DLL)
	mv lcrypt.so ../../

rebuild:
	$(CC) -o lcrypt.so lcrypt.c crc.c sha1.c sha256.c $(INCLUDE) $(LIB) $(CFLAGS) $(DLL)
	mv lcrypt.so ../../

clean:
	rm -rf *.o *.so
