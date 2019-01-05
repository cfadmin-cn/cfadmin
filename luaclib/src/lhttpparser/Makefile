.PHONY : build rebuild clean

default :
	@echo "======================================="
	@echo "Please use 'make build' command to build it.."
	@echo "Please use 'make clean' command to clean all."
	@echo "======================================="

CC = cc

# 如果确认是intel的CPU并且有SSE4可以自行开启这个编译参数, 经过测试http解析速度至少快2倍
# 这里为了兼容AMD CPU不作为默认开启选项
# CFLAGS = -O3 -Wall -DNDEBUG -fPIC -msse4

CFLAGS = -O3 -Wall -DNDEBUG -fPIC 

INCLUDE = -I/usr/local/include
LIB = -L/usr/local/lib -L../ -L../../ -L../../../

httpparser.o: httpparser.c httpparser.h
lhttpparser.o: lhttpparser.c httpparser.h

OBJS = httpparser.o lhttpparser.o

build: $(OBJS)
	$(CC) -o httpparser.so $(OBJS) $(INCLUDE) $(LIB) -O3 -shared -fPIC -lcore
	mv httpparser.so ../../

rebuild: $(OBJS)
	$(CC) -o httpparser.so $(OBJS) $(INCLUDE) $(LIB) -O3 -shared -fPIC -lcore
	rm -rf *.o
	mv httpparser.so ../../

clean:
	rm -rf *.o *.so
