.PHONY : build rebuild clean

default :
	@echo "======================================="
	@echo "Please use 'make build' command to build it.."
	@echo "Please use 'make rebuild' command to build it.."
	@echo "Please use 'make clean' command to clean all."
	@echo "======================================="

# CFLAGS = -O3 -Wall -DJEMALLOC -shared -fPIC -ljemalloc
# CFLAGS = -O3 -Wall -DTCMALLOC -shared -fPIC -ltcmalloc
CFLAGS = -O3 -Wall -shared -fPIC
CC = cc

INCLUDES = -I../../../src -I/usr/local/include
LIBS = -L../ -L../../ -L../../../ -L/usr/local/lib
DLL = -lcore

build:
	@$(CC) -o cjson.so lua_cjson.c fpconv.c strbuf.c $(INCLUDES) $(LIBS) $(CFLAGS) $(DLL)
	@mv *.so ../../
