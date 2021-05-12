.PHONY : build rebuild clean

default :
	@echo "======================================="
	@echo "Please use 'make build' command to build it.."
	@echo "Please use 'make rebuild' command to build it.."
	@echo "Please use 'make clean' command to clean all."
	@echo "======================================="

CC = cc

CFLAGS = -O3 -Wall -shared -fPIC -fno-strict-aliasing
DLL = -lcore -lcrypto

INCLUDES = -I../../../src -I/usr/local/include
LIBS = -L../ -L../../ -L../../../ -L/usr/local/lib

build:
	@$(CC) -o lcrypt.so lcrypt.c aes.c des.c dh.c rsa.c sha.c hmac.c hmac_ex.c b64.c crc.c url.c hex.c uuid.c sm.c rc.c $(INCLUDES) $(LIBS) $(CFLAGS) $(DLL)
	@mv *.so ../../
