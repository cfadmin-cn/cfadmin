.PHONY : build rebuild clean

default :
	@echo "======================================="
	@echo "Please use 'make build' command to build it.."
	@echo "Please use 'make rebuild' command to build it.."
	@echo "Please use 'make clean' command to clean all."
	@echo "======================================="

CC = gcc
LIBS = -L/usr/local/lib -L../ -L../../../

build:
	$(CC) -o lpeg.so lpcap.c lpcode.c lpprint.c lptree.c lpvm.c -O2 -shared -fPIC $(LIBS) -lcore
	mv *.so ../../

rebuild:
	$(CC) -o lpeg.so lpcap.c lpcode.c lpprint.c lptree.c lpvm.c -O2 -shared -fPIC $(LIBS) -lcore
	mv *.so ../../

clean:
	rm -f *.so *.o
