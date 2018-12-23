.PHONY : build rebuild clean

default :
	@echo "======================================="
	@echo "Please use 'make build' command to build it.."
	@echo "Please use 'make clean' command to clean all."
	@echo "======================================="

MACRO = -Wall -Os -fPIC --shared
CC = cc

build :
	$(CC) -o tcp.so src/ltcp.c $(MACRO) -lssl -lcrypto ../core.so
	$(CC) -o udp.so src/ludp.c $(MACRO) ../core.so
	$(CC) -o timer.so src/ltimer.c $(MACRO) ../core.so
	$(CC) -o task.so src/ltask.c $(MACRO) ../core.so
	$(CC) -o crypt.so src/lcrypt.c $(MACRO) ../core.so
	### 以下为预留第三方库编译位置 ###
	cd src/lcjson && make build # 增加cjson库

rebuild :
	rm -rf *.so
	$(CC) -o tcp.so src/ltcp.c $(MACRO) -lssl -lcrypto ../core.so
	$(CC) -o udp.so src/ludp.c $(MACRO) ../core.so
	$(CC) -o timer.so src/ltimer.c $(MACRO) ../core.so
	$(CC) -o task.so src/ltask.c $(MACRO) ../core.so
	$(CC) -o crypt.so src/lcrypt.c $(MACRO) ../core.so
	### 以下为预留第三方库编译位置 ###
	cd src/lcjson && make rebuild # 增加cjson库

clean :
	rm -rf *.so
