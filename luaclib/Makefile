.PHONY : build rebuild clean

default :
	@echo "======================================="
	@echo "Please use 'make build' command to build it.."
	@echo "Please use 'make clean' command to clean all."
	@echo "======================================="

MACRO += -Wall -Os -fPIC --shared


build :
	cc -o tcp.so src/ltcp.c $(MACRO) -lssl -lcrypto ../core.so
	cc -o udp.so src/ludp.c $(MACRO) ../core.so
	cc -o timer.so src/ltimer.c $(MACRO) ../core.so
	### 以下为预留clib编译位置 ###
	cc -o crypt.so src/lcrypt.c $(MACRO) ../core.so

rebuild :
	rm -rf *.so
	cc -o tcp.so src/ltcp.c $(MACRO) -lssl -lcrypto ../core.so
	cc -o udp.so src/ludp.c $(MACRO) ../core.so
	cc -o timer.so src/ltimer.c $(MACRO) ../core.so
	### 以下为预留clib编译位置 ###
	cc -o crypt.so src/lcrypt.c $(MACRO) ../core.so

clean :
	rm -rf *.so