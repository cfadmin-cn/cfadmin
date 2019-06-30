.PHONY : build rebuild clean

default :
	@echo "======================================="
	@echo "Please use 'make build' command to build it.."
	@echo "Please use 'make rebuild' command to build it.."
	@echo "Please use 'make clean' command to clean all."
	@echo "======================================="

CC = cc

# 如果确认是intel的CPU并且有SSE4可以自行开启这个编译参数, 经过测试http解析速度至少快2倍
# 这里为了兼容AMD CPU不作为默认开启选项
# CFLAGS = -O3 -w -shared -fPIC -DNDEBUG -msse4

CFLAGS = -O3 -w -shared -fPIC -DNDEBUG

DLL =  -lcore

INCLUDE = -I/usr/local/include
LIB = -L/usr/local/lib -L../ -L../../../


build:
	$(CC) -o httpparser.so httpparser.c lhttpparser.c $(INCLUDE) $(LIB) $(CFLAGS) $(DLL)
	mv httpparser.so ../../

rebuild:
	$(CC) -o httpparser.so httpparser.c lhttpparser.c $(INCLUDE) $(LIB) $(CFLAGS) $(DLL)
	mv httpparser.so ../../

clean:
	rm -rf *.o *.so
