.PHONY : build rebuild clean

default :
	@echo "======================================="
	@echo "Please use 'make build' command to build it.."
	@echo "======================================="

CC = cc

LIBS += -L/usr/local/lib

INCLUDES += -I/usr/local/include

CFLAGS += -Wall -O2 -fPIC --shared -static

MACRO += -Wall -O2 -DJEMALLOC

DLL += -ljemalloc -lev -lssl -llua -lm

build :

	$(CC) -o core.so core.c $(CFLAGS) $(INCLUDES) $(LIBS) $(DLL) 

	$(CC) core_start.c -o main $(MACRO) core.so

rebuild:
	rm -rf *.o *.so

	$(CC) -o core.so core.c $(CFLAGS) $(INCLUDES) $(LIBS) $(DLL) 

	$(CC) core_start.c -o main $(MACRO) core.so

clean :
	rm -rf *.o *.so