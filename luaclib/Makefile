.PHONY : build rebuild clean

default :
	@echo "======================================="
	@echo "Please use 'make build' command to build it.."
	@echo "Please use 'make clean' command to clean all."
	@echo "======================================="

MACRO = -Wall -Os -fPIC --shared -L./ -L../

build :

	$(CC) -o tcp.so src/ltcp.c $(MACRO) -lssl -lcrypto -lcore
	$(CC) -o snapshot.so src/lsnapshot.c $(MACRO) -lcore
	$(CC) -o udp.so src/ludp.c $(MACRO) -lcore
	$(CC) -o timer.so src/ltimer.c $(MACRO) -lcore
	$(CC) -o task.so src/ltask.c $(MACRO) -lcore
	$(CC) -o crypt.so src/lcrypt.c $(MACRO) -lcore
	### 以下为预留第三方库编译位置 ###
	cd src/lcjson && make build # 增加cjson库

rebuild :

	rm -rf *.so
	$(CC) -o tcp.so src/ltcp.c $(MACRO) -lssl -lcrypto -lcore
	$(CC) -o snapshot.so src/lsnapshot.c $(MACRO) -lcore
	$(CC) -o udp.so src/ludp.c $(MACRO) -lcore
	$(CC) -o timer.so src/ltimer.c $(MACRO) -lcore
	$(CC) -o task.so src/ltask.c $(MACRO) -lcore
	$(CC) -o crypt.so src/lcrypt.c $(MACRO) -lcore
	### 以下为预留第三方库编译位置 ###
	cd src/lcjson && make rebuild # 增加cjson库

clean :
	rm -rf *.so
