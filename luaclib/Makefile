.PHONY : build rebuild clean

default :
	@echo "======================================="
	@echo "Please use 'make build' command to build it.."
	@echo "Please use 'make clean' command to clean all."
	@echo "======================================="

INCLUDES += -I/usr/local/include 
LIBS += -L/usr/local/lib -L./ -L../
# CFLAGS = -Wall -Os -fPIC --shared -I/usr/local/include -L./ -L../ -DJEMALLOC -ljemalloc
# CFLAGS = -Wall -Os -fPIC --shared -I/usr/local/include -L./ -L../ -DTCMALLOC -ltcmalloc
CFLAGS = -Wall -Os -fPIC --shared

build :

	$(CC) -o sys.so src/lsys.c $(CFLAGS) $(INCLUDES) $(LIBS) -lcore
	$(CC) -o tcp.so src/ltcp.c $(CFLAGS) $(INCLUDES) $(LIBS) -lssl -lcrypto -lcore
	$(CC) -o udp.so src/ludp.c $(CFLAGS) $(INCLUDES) $(LIBS) -lcore
	$(CC) -o timer.so src/ltimer.c $(CFLAGS) $(INCLUDES) $(LIBS) -lcore
	$(CC) -o task.so src/ltask.c $(CFLAGS) $(INCLUDES) $(LIBS) -lcore
	$(CC) -o crypt.so src/lcrypt.c $(CFLAGS) $(INCLUDES) $(LIBS) -lcore
	### 以下为预留第三方库编译位置 ###
	cd src/lhttpparser && make build # 增加PicoHTTPParser库
	cd src/lcjson && make build 	 # 增加cjson库

rebuild :

	rm -rf *.so
	$(CC) -o sys.so src/lsys.c $(CFLAGS) $(INCLUDES) $(LIBS) -lcore
	$(CC) -o tcp.so src/ltcp.c $(CFLAGS) $(INCLUDES) $(LIBS) -lssl -lcrypto -lcore
	$(CC) -o udp.so src/ludp.c $(CFLAGS) $(INCLUDES) $(LIBS) -lcore
	$(CC) -o timer.so src/ltimer.c $(CFLAGS) $(INCLUDES) $(LIBS) -lcore
	$(CC) -o task.so src/ltask.c $(CFLAGS) $(INCLUDES) $(LIBS) -lcore
	$(CC) -o crypt.so src/lcrypt.c $(CFLAGS) $(INCLUDES) $(LIBS) -lcore
	### 以下为预留第三方库编译位置 ###
	cd src/lhttpparser && make build # 增加PicoHTTPParser库
	cd src/lcjson && make rebuild # 增加cjson库

clean :
	rm -rf *.so
