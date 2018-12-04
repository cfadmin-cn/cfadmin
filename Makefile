.PHONY : build clean

default :
	@echo "======================================="
	@echo "Please use 'make build' command to build it.."
	@echo "Please use 'make clean' command to clean all."
	@echo "======================================="

build :
	cd src && make build && mv main ../main && mv *.so ../
	cd luaclib && cd src && cc -o crypt.so lsha1.c lua_crypt.c -fPIC -shared -llua

rebuild :
	rm -rf main *.so
	cd src && make clean
	cd luaclib && make clean
	cd src && make build && mv main ../main && mv *.so ../
	cd luaclib && make build

clean :
	rm -rf main *.so && cd src && make clean