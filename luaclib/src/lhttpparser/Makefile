.PHONY : build rebuild clean

default :
	@echo "======================================="
	@echo "Please use 'make build' command to build it.."
	@echo "Please use 'make rebuild' command to build it.."
	@echo "Please use 'make clean' command to clean all."
	@echo "======================================="

CC = cc

# 开启请先确认是否支持指令集, 经过测试http解析速度至少快2倍
# CFLAGS = -O3 -Wall -shared -fPIC -msse4

INCLUDE = -I/usr/local/include
LIB = -L/usr/local/lib -L../ -L../../../

CFLAGS = -O3 -Wall -shared -fPIC
DLL = -lcore


build:
	$(CC) -o httpparser.so httpparser.c lhttpparser.c $(INCLUDE) $(LIB) $(CFLAGS) $(DLL)
	mv httpparser.so ../../

rebuild:
	$(CC) -o httpparser.so httpparser.c lhttpparser.c $(INCLUDE) $(LIB) $(CFLAGS) $(DLL)
	mv httpparser.so ../../

clean:
	rm -rf *.o *.so
