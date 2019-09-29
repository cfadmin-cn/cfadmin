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

	@$(MAKE) -s -C src build
	@$(MAKE) -s -C luaclib internal
	@$(MAKE) -s -C luaclib 3part
	@$(MAKE) -s -C 3rd build

rebuild :

	@$(MAKE) -s -C src build
	@$(MAKE) -s -C luaclib internal
	@$(MAKE) -s -C luaclib 3part
	@$(MAKE) -s -C 3rd build

clean :
	@echo "********** Clean All Files **********"
	rm -rf cfadmin libcore.so luaclib/*.so
	@$(MAKE) -s -C 3rd clean
