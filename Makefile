.PHONY : build rebuild clean

default :
	@echo "======================================="
	@echo "Please use 'make build' command to build it.."
	@echo "Please use 'make rebuild' command to build it.."
	@echo "Please use 'make clean' command to clean all."
	@echo "======================================="

# 如果需要修改内存分配器,请修改:
# 1. src/Makefile
# 2. lualib/Makefile
# 3. lualib/src/cjson/Makefile

build :
	cd src && make build
	cd luaclib && make build
	cd 3rd && make build

rebuild :
	rm -rf main cfadmin *.so
	cd src && make clean && make rebuild
	cd luaclib && make clean && make rebuild
	cd 3rd && make clean && make rebuild

clean :
	rm -rf main cfadmin *.so
	cd src && make clean
	cd luaclib && make clean
	cd 3rd && make clean
