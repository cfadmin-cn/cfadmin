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

INCLUDES += -I../../../src -I/usr/local/include
LIBS = -L../ -L../../../ -L/usr/local/lib

CFLAGS = -O3 -Wall -shared -fPIC
DLL = -lcore -llua


build:
	$(CC) -o httpparser.so httpparser.c lhttpparser.c $(INCLUDES) $(LIBS) $(CFLAGS) $(DLL)
	mv *.so ../../

rebuild:
	$(CC) -o httpparser.so httpparser.c lhttpparser.c $(INCLUDES) $(LIBS) $(CFLAGS) $(DLL)
	mv *.so ../../

clean:
	rm -rf *.o *.so
