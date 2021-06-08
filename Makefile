.PHONY : build rebuild clean

RM = rm -rf

default :
	@echo "======================================="
	@echo "Please use 'make build' command to build it.."
	@echo "Please use 'make rebuild' command to rebuild it.."
	@echo "Please use 'make clean' command to clean all."
	@echo "======================================="

# 如果需要修改内存分配器,请修改:
# 1. src/Makefile
# 2. luaclib/Makefile

build :
	@$(MAKE) -s -C src build
	@echo "********** Built-in core modules **********"
	@cd luaclib && $(MAKE) -s internal 3part -j4
	@$(MAKE) -s -C 3rd build

rebuild :
	@$(MAKE) -s clean
	@$(MAKE) -s build

clean :
	@echo "********** Clean All Files **********"
	@echo "rm -rf cfadmin libcore luaclib/*.so 3rd/*.so"
	@$(RM) cfadmin cfadmin.exe libcore.so libcore.dll luaclib/*.so
	@$(MAKE) -s -C 3rd clean