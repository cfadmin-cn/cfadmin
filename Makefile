.PHONY : build clean

default :
	@echo "======================================="
	@echo "Please use 'make build' command to build it.."
	@echo "Please use 'make clean' command to clean all."
	@echo "======================================="

build :
	cd src && make build && mv main ../main && mv *.so ../

rebuild :
	rm -rf main *.so && cd src && make clean
	cd src && make build && mv main ../main && mv *.so ../

clean :
	rm -rf main *.so && cd src && make clean