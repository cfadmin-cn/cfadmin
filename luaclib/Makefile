.PHONY : build rebuild clean

default :
	@echo "======================================="
	@echo "Please use 'make build' command to build it.."
	@echo "Please use 'make clean' command to clean all."
	@echo "======================================="

MACRO += -Wall -O2 -fPIC --shared

# DLL += -llua -lssl -lm
DLL += 

build :
	cc -o tcp.so src/ltcp.c ../core.so $(MACRO) $(DLL)
	cc -o udp.so src/ludp.c ../core.so $(MACRO) $(DLL)
	cc -o timer.so src/ltimer.c ../core.so $(MACRO) $(DLL)
	cc -o crypt.so src/lsha1.c src/lua_crypt.c $(MACRO) $(DLL)

rebuild :
	rm -rf *.so
	cc -o tcp.so src/ltcp.c ../core.so $(MACRO) $(DLL)
	cc -o udp.so src/ludp.c ../core.so $(MACRO) $(DLL)
	cc -o timer.so src/ltimer.c ../core.so $(MACRO) $(DLL)
	cc -o crypt.so src/lsha1.c src/lua_crypt.c $(MACRO) $(DLL)

clean :
	rm -rf *.so