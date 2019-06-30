.PHONY : build rebuild clean

default :
	@echo "======================================="
	@echo "Please use 'make build' command to build it.."
	@echo "Please use 'make rebuild' command to build it.."
	@echo "Please use 'make clean' command to clean all."
	@echo "======================================="

INCLUDES += -I/usr/local/include
LIBS += -L./ -L../ -L/usr/local/lib
# CFLAGS = -Wall -O3 -fPIC --shared -DJEMALLOC -ljemalloc
# CFLAGS = -Wall -O3 -fPIC --shared -DTCMALLOC -ltcmalloc
CFLAGS = -Wall -O3 -fPIC --shared

build :
	$(CC) -o sys.so src/lsys.c $(CFLAGS) $(INCLUDES) $(LIBS) -lcore
	$(CC) -o udp.so src/ludp.c $(CFLAGS) $(INCLUDES) $(LIBS) -lcore
	$(CC) -o task.so src/ltask.c $(CFLAGS) $(INCLUDES) $(LIBS) -lcore
	$(CC) -o timer.so src/ltimer.c $(CFLAGS) $(INCLUDES) $(LIBS) -lcore
	$(CC) -o tcp.so src/ltcp.c $(CFLAGS) $(INCLUDES) $(LIBS) -lssl -lcrypto -lcore
	### 以下为内置第三方库编译位置 ###
	cd src/lpeg && rm -rf *.o *.so && make build 	  # 增加lpeg库
	cd src/lcrypt && rm -rf *.o *.so && make build  # 增加crypt库
	cd src/lcjson && rm -rf *.o *.so && make build 	# 增加cjson库
	cd src/lhttpparser && rm -rf *.o *.so && make build # 增加PicoHTTPParser库

rebuild :
	$(CC) -o sys.so src/lsys.c $(CFLAGS) $(INCLUDES) $(LIBS) -lcore
	$(CC) -o udp.so src/ludp.c $(CFLAGS) $(INCLUDES) $(LIBS) -lcore
	$(CC) -o task.so src/ltask.c $(CFLAGS) $(INCLUDES) $(LIBS) -lcore
	$(CC) -o timer.so src/ltimer.c $(CFLAGS) $(INCLUDES) $(LIBS) -lcore
	$(CC) -o tcp.so src/ltcp.c $(CFLAGS) $(INCLUDES) $(LIBS) -lssl -lcrypto -lcore
	### 以下为内置第三方库编译位置 ###
	cd src/lpeg && rm -rf *.o *.so && make build 	  # 增加lpeg库
	cd src/lcrypt && rm -rf *.o *.so && make build  # 增加crypt库
	cd src/lcjson && rm -rf *.o *.so && make build 	# 增加cjson库
	cd src/lhttpparser && rm -rf *.o *.so && make build # 增加PicoHTTPParser库

clean :
	rm -rf *.so
