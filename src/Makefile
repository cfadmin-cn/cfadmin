.PHONY : build rebuild clean

default :
	@echo "======================================="
	@echo "Please use 'make clean' command to clean it.."
	@echo "Please use 'make build' command to build it.."
	@echo "Please use 'make rebuild' command  DEBUG it.."
	@echo "======================================="

CC = cc

LIBS += -L. -L../ -L/usr/local/lib
INCLUDES += -I. -I../ -I/usr/local/include

# 使用jemalloc内存分配器请启用这段
# CFLAGS += -Wall -O3 -fPIC --shared -DJEMALLOC -fno-strict-aliasing -Wl,-rpath,. -Wl,-rpath,.. -Wl,-rpath,/usr/local/lib
# MACRO += -O3 -Wl,-rpath,. -Wl,-rpath,.. -Wl,-rpath,/usr/local/lib/ -DJEMALLOC
# DLL += -ljemalloc -lev -llua -ldl -lm

# 使用tcmalloc内存分配器请启用这段
# CFLAGS += -Wall -O3 -fPIC --shared -DTCMALLOC -fno-strict-aliasing -Wl,-rpath,. -Wl,-rpath,.. -Wl,-rpath,/usr/local/lib
# MACRO += -O3 -Wl,-rpath,. -Wl,-rpath,.. -Wl,-rpath,/usr/local/lib -DTCMALLOC
# DLL += -ltcmalloc -lev -llua -ldl -lm

# 默认情况下使用系统内存分配器
CFLAGS += -Wall -O3 -fPIC --shared -fno-strict-aliasing -Wl,-rpath,. -Wl,-rpath,.. -Wl,-rpath,/usr/local/lib
MACRO += -O3 -Wl,-rpath,. -Wl,-rpath,.. -Wl,-rpath,/usr/local/lib
DLL += -lev -llua -ldl -lm

build :
	@echo "********** Core library and executable **********"
	@if [ "`uname -s`" = 'Linux' ] || [ "`uname -s`" = 'Android' ] || [ "`uname -s`" = 'Darwin' ] || \
	    [ "`uname -s`" = 'FreeBSD' ] || [ "`uname -s`" = 'OpenBSD' ] || [ "`uname -s`" = 'NetBSD' ] || [ "`uname -s`" = 'DragonFlyBSD' ] \
	; then \
		$$@echo "CC	-	libcore" ; \
		$$@cc -o libcore.so core.c core_ev.c core_memory.c core_sys.c $(CFLAGS) $(INCLUDES) $(LIBS) $(DLL) ; \
		$$@echo "CC	-	cfadmin" ; \
		$$@cc -o cfadmin core_start.c $(MACRO) $(INCLUDES) $(LIBS) -lcore ; \
		$$@mv *.so cfadmin ../ ; \
	else \
		$$@echo "CC	-	libcore" ; \
		$$@cc -o libcore.dll core.c core_ev.c core_memory.c core_sys.c $(CFLAGS) $(INCLUDES) $(LIBS) $(DLL) ; \
		$$@echo "CC	-	cfadmin" ; \
		$$@cc -o cfadmin.exe core_start.c $(MACRO) $(INCLUDES) $(LIBS) -lcore ; \
		$$@mv *.dll cfadmin.exe ../ ; \
	fi;