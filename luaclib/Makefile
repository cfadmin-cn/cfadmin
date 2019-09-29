.PHONY : build rebuild clean

default :
	@echo "======================================="
	@echo "Please use 'make build' command to build it.."
	@echo "Please use 'make rebuild' command to build it.."
	@echo "Please use 'make clean' command to clean all."
	@echo "======================================="

INCLUDES += -I../src -I/usr/local/include
LIBS += -L./ -L../ -L/usr/local/lib
# CFLAGS = -Wall -O3 -fPIC --shared -DJEMALLOC -ljemalloc
# CFLAGS = -Wall -O3 -fPIC --shared -DTCMALLOC -ltcmalloc
CFLAGS = -Wall -O3 -fPIC --shared

build :

	### 以下为内置模块位置 ###
	@echo "CC	-	lsys"
	@$(CC) -o sys.so src/lsys.c $(CFLAGS) $(INCLUDES) $(LIBS) -lcore -llua
	@echo "CC	-	ludp"
	@$(CC) -o udp.so src/ludp.c $(CFLAGS) $(INCLUDES) $(LIBS) -lcore -llua
	@echo "CC	-	ltask"
	@$(CC) -o task.so src/ltask.c $(CFLAGS) $(INCLUDES) $(LIBS) -lcore -llua
	@echo "CC	-	ltimer"
	@$(CC) -o timer.so src/ltimer.c $(CFLAGS) $(INCLUDES) $(LIBS) -lcore -llua
	@echo "CC	-	ltcp"
	@$(CC) -o tcp.so src/ltcp.c $(CFLAGS) $(INCLUDES) $(LIBS) -lssl -lcrypto -lcore -llua
	### 以下为内置第三方库编译位置 ###
	@echo "CC	-	lfs"
	@$(MAKE) -C src/lfs build

	@echo "CC	-	lffi"
	@$(MAKE) -C src/lffi build

	@echo "CC	-	lpbc"
	@$(MAKE) -C src/lpbc build

	@echo "CC	-	lpeg"
	@$(MAKE) -C src/lpeg build

	@echo "CC	-	lcrypt"
	@$(MAKE) -C src/lcrypt build

	@echo "CC	-	lcjson"
	@$(MAKE) -C src/lcjson build

	@echo "CC	-	lmsgpack"
	@$(MAKE) -C src/lmsgpack build

	@echo "CC	-	lhttpparser"
	@$(MAKE) -C src/lhttpparser build

rebuild :

	### 以下为内置模块位置 ###
	@echo "CC	-	lsys"
	@$(CC) -o sys.so src/lsys.c $(CFLAGS) $(INCLUDES) $(LIBS) -lcore -llua
	@echo "CC	-	ludp"
	@$(CC) -o udp.so src/ludp.c $(CFLAGS) $(INCLUDES) $(LIBS) -lcore -llua
	@echo "CC	-	ltask"
	@$(CC) -o task.so src/ltask.c $(CFLAGS) $(INCLUDES) $(LIBS) -lcore -llua
	@echo "CC	-	ltimer"
	@$(CC) -o timer.so src/ltimer.c $(CFLAGS) $(INCLUDES) $(LIBS) -lcore -llua
	@echo "CC	-	ltcp"
	@$(CC) -o tcp.so src/ltcp.c $(CFLAGS) $(INCLUDES) $(LIBS) -lssl -lcrypto -lcore -llua
	### 以下为内置第三方库编译位置 ###
	@echo "CC	-	lfs"
	@$(MAKE) -C src/lfs build

	@echo "CC	-	lffi"
	@$(MAKE) -C src/lffi build

	@echo "CC	-	lpbc"
	@$(MAKE) -C src/lpbc build

	@echo "CC	-	lpeg"
	@$(MAKE) -C src/lpeg build

	@echo "CC	-	lcrypt"
	@$(MAKE) -C src/lcrypt build

	@echo "CC	-	lcjson"
	@$(MAKE) -C src/lcjson build

	@echo "CC	-	lmsgpack"
	@$(MAKE) -C src/lmsgpack build

	@echo "CC	-	lhttpparser"
	@$(MAKE) -C src/lhttpparser build
