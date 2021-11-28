.PHONY : build rebuild clean

default :
	@echo "======================================="
	@echo "Please use 'make build' command to build it.."
	@echo "Please use 'make rebuild' command to build it.."
	@echo "Please use 'make clean' command to clean all."
	@echo "======================================="

INCLUDES += -I../src -I/usr/local/include
LIBS += -L./ -L../ -L/usr/local/lib
# CFLAGS = -Wall -O3 -fPIC --shared -DJEMALLOC -ljemalloc -Wl,-rpath,. -Wl,-rpath,.. -Wl,-rpath,/usr/local/lib
# CFLAGS = -Wall -O3 -fPIC --shared -DTCMALLOC -ltcmalloc -Wl,-rpath,. -Wl,-rpath,.. -Wl,-rpath,/usr/local/lib
CFLAGS = -Wall -O3 -fPIC --shared -Wno-unused-function -Wl,-rpath,. -Wl,-rpath,.. -Wl,-rpath,/usr/local/lib

internal :
	@echo "CC	-	lsys"
	@$(CC) -o sys.so src/lsys.c $(CFLAGS) $(INCLUDES) $(LIBS) -lcore
	@echo "CC	-	lpack"
	@$(CC) -o pack.so src/lpack.c $(CFLAGS) $(INCLUDES) $(LIBS) -lcore
	@echo "CC	-	lchild"
	@$(CC) -o child.so src/lchild.c $(CFLAGS) $(INCLUDES) $(LIBS) -lcore
	@echo "CC	-	ludp"
	@$(CC) -o udp.so src/ludp.c $(CFLAGS) $(INCLUDES) $(LIBS) -lcore
	@echo "CC	-	ltask"
	@$(CC) -o task.so src/ltask.c $(CFLAGS) $(INCLUDES) $(LIBS) -lcore
	@echo "CC	-	ltimer"
	@$(CC) -o timer.so src/ltimer.c $(CFLAGS) $(INCLUDES) $(LIBS) -lcore
	@echo "CC	-	laio"
	@$(CC) -o laio.so src/laio.c $(CFLAGS) $(INCLUDES) $(LIBS) -lcore -leio -lpthread
	@echo "CC	-	ltcp"
	@$(CC) -o tcp.so src/ltcp.c $(CFLAGS) $(INCLUDES) $(LIBS) -lcore -lssl -lcrypto

3part :
	@echo "CC	-	lz"
	@$(MAKE) -C src/lz build
	@echo "CC	-	lfs"
	@$(MAKE) -C src/lfs build
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
