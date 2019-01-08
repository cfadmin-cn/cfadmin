.PHONY : build rebuild clean

default :
	@echo "======================================="
	@echo "Please use 'make build' command to build it.."
	@echo "Please use 'make clean' command to clean all."
	@echo "======================================="

# CFLAGS = -Wall -Os -fPIC --shared -L./ -L../ -DJEMALLOC -ljemalloc
# CFLAGS = -Wall -Os -fPIC --shared -L./ -L../ -DTCMALLOC -ltcmalloc
CFLAGS = -Wall -Os -fPIC --shared -L./ -L../

build :

	$(CC) -o tcp.so src/ltcp.c $(CFLAGS) -lssl -lcrypto -lcore
	$(CC) -o snapshot.so src/lsnapshot.c $(CFLAGS) -lcore
	$(CC) -o udp.so src/ludp.c $(CFLAGS) -lcore
	$(CC) -o timer.so src/ltimer.c $(CFLAGS) -lcore
	$(CC) -o task.so src/ltask.c $(CFLAGS) -lcore
	$(CC) -o crypt.so src/lcrypt.c $(CFLAGS) -lcore
	### 以下为预留第三方库编译位置 ###
	cd src/lhttpparser && make build # 增加PicoHTTPParser库
	cd src/lcjson && make build 	 # 增加cjson库

rebuild :

	rm -rf *.so
	$(CC) -o tcp.so src/ltcp.c $(CFLAGS) -lssl -lcrypto -lcore
	$(CC) -o snapshot.so src/lsnapshot.c $(CFLAGS) -lcore
	$(CC) -o udp.so src/ludp.c $(CFLAGS) -lcore
	$(CC) -o timer.so src/ltimer.c $(CFLAGS) -lcore
	$(CC) -o task.so src/ltask.c $(CFLAGS) -lcore
	$(CC) -o crypt.so src/lcrypt.c $(CFLAGS) -lcore
	### 以下为预留第三方库编译位置 ###
	cd src/lhttpparser && make build # 增加PicoHTTPParser库
	cd src/lcjson && make rebuild # 增加cjson库

clean :
	rm -rf *.so
