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

INCLUDE = -I/usr/local/include
LIB = -L/usr/local/lib -L../ -L../../../

build:
	$(CC) -o cjson.so lua_cjson.c fpconv.c strbuf.c $(INCLUDE) $(LIB) $(CFLAGS) -lcore
	mv cjson.so ../../

rebuild: $(OBJS)
	$(CC) -o cjson.so lua_cjson.c fpconv.c strbuf.c $(INCLUDE) $(LIB) $(CFLAGS) -lcore
	mv cjson.so ../../

clean:
	rm -rf *.o *.so
