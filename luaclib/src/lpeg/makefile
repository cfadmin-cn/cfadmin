.PHONY : build rebuild clean

default :
	@echo "======================================="
	@echo "Please use 'make build' command to build it.."
	@echo "Please use 'make rebuild' command to build it.."
	@echo "Please use 'make clean' command to clean all."
	@echo "======================================="

CC = cc
LIBS = -L/usr/local/lib -L../ -L../../../
CFLAGS = -O3 -shared -fPIC
DLL = -lcore

build:
	$(CC) -o lpeg.so lpcap.c lpcode.c lpprint.c lptree.c lpvm.c $(CFLAGS) $(LIBS) $(DLL)
	mv *.so ../../

rebuild:
	$(CC) -o lpeg.so lpcap.c lpcode.c lpprint.c lptree.c lpvm.c $(CFLAGS) $(LIBS) $(DLL)
	mv *.so ../../

clean:
	rm -f *.so *.o
