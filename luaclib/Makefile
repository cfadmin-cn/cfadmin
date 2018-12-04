.PHONY : build rebuild clean

default :
	@echo "======================================="
	@echo "Please use 'make build' command to build it.."
	@echo "Please use 'make clean' command to clean all."
	@echo "======================================="

build :
	cc -o crypt.so src/lsha1.c src/lua_crypt.c -fPIC -shared ../core_event.so

rebuild :
	rm -rf *.so
	cc -o crypt.so src/lsha1.c src/lua_crypt.c -fPIC -shared ../core_event.so #-llua

clean :
	rm -rf *.so