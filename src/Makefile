.PHONY : build rebuild clean

default :
	@echo "======================================="
	@echo "Please use 'make clean' command to clean it.."
	@echo "Please use 'make build' command to build it.."
	@echo "Please use 'make rebuild' command  DEBUG it.."
	@echo "======================================="

CC = cc

LIBS += -L/usr/local/lib
INCLUDES += -I/usr/local/include

# 使用jemalloc内存分配器请启用这段
# CFLAGS += -Wall -Os -fPIC --shared -DJEMALLOC
# DLL += -ljemalloc -lev -llua
# MACRO += -w -Os -L./ -L../ -DJEMALLOC

# 使用tcmalloc内存分配器请启用这段
# CFLAGS += -Wall -Os -fPIC --shared -DTCMALLOC
# DLL += -ltcmalloc -lev -llua
# MACRO += -w -Os -L./ -L../ -DTCMALLOC

# 默认情况下使用系统内存分配器
CFLAGS += -Wall -Os -fPIC --shared
DLL += -lev -llua
MACRO += -w -Os

build :

	$(CC) -o libcore.so core.c core_memory.c core_sys.c $(CFLAGS) $(INCLUDES) $(LIBS) $(DLL)

	mv *.so /usr/local/lib

	$(CC) core_start.c -o cfadmin $(MACRO) -ldl -lcore

	mv cfadmin ../

rebuild:

	rm -rf *.o *.so

	$(CC) -o libcore.so core.c core_memory.c core_sys.c $(CFLAGS) $(INCLUDES) $(LIBS) $(DLL)

	mv *.so /usr/local/lib

	$(CC) core_start.c -o cfadmin $(MACRO) -ldl -lcore

	mv cfadmin ../

clean :

	rm -rf *.o *.so
