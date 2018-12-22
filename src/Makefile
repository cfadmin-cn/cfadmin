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

# CFLAGS += -Wall -DJEMALLOC -Os -fPIC --shared

# DLL += -ljemalloc -lev -llua

CFLAGS += -Wall -Os -fPIC --shared

DLL += -lev -llua

MACRO += -Wall -Os  -ggdb

build :

	$(CC) -o core.so core.c $(CFLAGS) $(INCLUDES) $(LIBS) $(DLL)

	$(CC) core_start.c -o main $(MACRO) core.so

rebuild:

	rm -rf *.o *.so

	$(CC) -o core.so core.c $(CFLAGS) $(INCLUDES) $(LIBS) $(DLL)

	$(CC) core_start.c -o main $(MACRO) core.so

clean :

	rm -rf *.o *.so
