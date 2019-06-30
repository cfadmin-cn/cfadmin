.PHONY : build rebuild clean

default :
	@echo "======================================="
	@echo "Please use 'make build' command to build it.."
	@echo "Please use 'make rebuild' command to build it.."
	@echo "Please use 'make clean' command to clean all."
	@echo "======================================="

# CFLAGS = -O3 -Wall -DNDEBUG -DJEMALLOC -ljemalloc
# CFLAGS = -O3 -Wall -DNDEBUG -DTCMALLOC -ltcmalloc
CFLAGS = -O3 -Wall -DNDEBUG
CC = cc

INCLUDE = -I/usr/local/include
LIB = -L/usr/local/lib -L../ -L../../../

build:
	$(CC) -o cjson.so lua_cjson.c fpconv.c strbuf.c $(INCLUDE) $(LIB) $(CFLAGS) -shared -fPIC -lcore
	mv cjson.so ../../

rebuild: $(OBJS)
	$(CC) -o cjson.so lua_cjson.c fpconv.c strbuf.c $(INCLUDE) $(LIB) $(CFLAGS) -shared -fPIC -lcore
	mv cjson.so ../../

clean:
	rm -rf *.o *.so
