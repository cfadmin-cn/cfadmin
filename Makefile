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

	### 编译核心库与可执行文件 ###
	@$(MAKE) -C src build
	@$(MAKE) -C luaclib build
	@$(MAKE) -C 3rd build

rebuild :

	### 编译核心库与可执行文件 ###
	@$(MAKE) -C src rebuild
	@$(MAKE) -C luaclib rebuild
	@$(MAKE) -C 3rd rebuild

clean :

	### 清理所有编译文件与库 ###
	rm -rf cfadmin libcore.so luaclib/*.so
