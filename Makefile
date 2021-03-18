.PHONY : build rebuild clean

RM = rm -rf

default :
	@echo "======================================="
	@echo "Please use 'make build' command to build it.."
	@echo "Please use 'make rebuild' command to build it.."
	@echo "Please use 'make clean' command to clean all."
	@echo "======================================="

# 如果需要修改内存分配器,请修改:
# 1. src/Makefile
# 2. luaclib/Makefile

build :
	@$(MAKE) -s -C src build
	@$(MAKE) -s -C luaclib internal
	@$(MAKE) -s -C luaclib 3part
	@$(MAKE) -s -C 3rd build

rebuild :
	@$(MAKE) -s clean
	@$(MAKE) -s build

clean :
	@echo "********** Clean All Files **********"
	@echo "rm -rf cfadmin libcore.so luaclib/*.so *.exe"
	@$(RM) cfadmin libcore.so luaclib/*.so *.exe
	@$(MAKE) -s -C 3rd clean
