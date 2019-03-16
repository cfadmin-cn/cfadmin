.PHONY : build clean

default :
	@echo "======================================="
	@echo "Please use 'make build' command to build it.."
	@echo "Please use 'make clean' command to clean all."
	@echo "======================================="

# 如果需要修改内存分配器,请修改:
# 1. src/Makefile
# 2. lualib/Makefile
# 3. lualib/src/cjson/Makefile

build :
	cd src && rm -rf *.so *.o && make build
	cd luaclib && rm -rf *.so *.o && make build

rebuild :
	rm -rf main cfadmin *.so
	cd src && rm -rf *.so *.o && make rebuild
	cd luaclib && rm -rf *.so *.o && make rebuild

clean :
	rm -rf main cfadmin *.so
	cd src && make clean
	cd luaclib && make clean