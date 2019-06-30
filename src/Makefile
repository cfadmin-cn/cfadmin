.PHONY : build rebuild clean

default :
	@echo "======================================="
	@echo "Please use 'make clean' command to clean it.."
	@echo "Please use 'make build' command to build it.."
	@echo "Please use 'make rebuild' command  DEBUG it.."
	@echo "======================================="

CC = cc

LIBS += -L. -L/usr/local/lib
INCLUDES += -I/usr/local/include

# 使用jemalloc内存分配器请启用这段
# CFLAGS += -Wall -Os -fPIC --shared -DJEMALLOC -fno-strict-aliasing
# DLL += -ljemalloc -lev -llua
# MACRO += -w -Os -L./ -L../ -DJEMALLOC

# 使用tcmalloc内存分配器请启用这段
# CFLAGS += -Wall -Os -fPIC --shared -DTCMALLOC -fno-strict-aliasing
# DLL += -ltcmalloc -lev -llua
# MACRO += -w -Os -L./ -L../ -DTCMALLOC

# 默认情况下使用系统内存分配器
CFLAGS += -Wall -O3 -fPIC --shared -fno-strict-aliasing -Wl,-rpath,/usr/local/lib
DLL += -lev -llua -ldl
MACRO += -w -O3 -Wl,-rpath,./

build :

	$(CC) -o libcore.so core.c core_ev.c core_memory.c core_sys.c $(CFLAGS) $(INCLUDES) $(LIBS) $(DLL)

	$(CC) -o cfadmin core_start.c $(MACRO) $(INCLUDES) $(LIBS) -lcore

	mv *.so cfadmin ../

rebuild:

	$(CC) -o libcore.so core.c core_ev.c core_memory.c core_sys.c $(CFLAGS) $(INCLUDES) $(LIBS) $(DLL)

	$(CC) -o cfadmin core_start.c $(MACRO) $(INCLUDES) $(LIBS) -lcore

	mv *.so cfadmin ../

clean :

	rm -rf *.o *.so
