# Run this file to install libev and lua; if you already have lua and libev in your environment, you can ignore this file and try to compile directly using makefile.
# 运行这个文件可以安装libev与lua; 如果您的环境中已经有了lua与libev后可以忽略此文件并且直接使用makefile尝试编译.

# This file must be executed in the current folder directory, otherwise the installation will be wrong. Beginners need to keep in mind.
# 必须在当前文件夹目录执行此文件, 否则安装将会出错. 初学者需要谨记.

# Before executing this build file, you need to make sure that these software environments are installed: gcc/clang autoconf automake make libtool git readline-devel openssl-devel.
# 执行这个编译文件之前需要确保安装了这些软件环境: gcc/clang autoconf automake make libtool git readline-devel openssl-devel. 如果未安装或者缺少安装, 请仔细检查并且自行尝试安装依赖环境.

set current=`pwd`

rm -rf build && mkdir build && cd build

git clone https://github.com/CandyMi/lua -b v5.3.5
git clone https://github.com/CandyMi/libev -b v4.25

cd ${current}/build/libev &&
  sh autogen.sh && ./configure --prefix=/usr/local &&
  make && cp e*.h ${current}/src && cp .libs/libev* ${current}/

cd ${current}/build/lua &&
  make all MYCFLAGS=-fPIC MYCFLAGS+=-DLUA_USE_POSIX MYCFLAGS+=-DLUA_USE_DLOPEN MYLIBS="-ldl -lreadline" &&
  cp lua.h luaconf.h lualib.h lauxlib.h ${current}/src && cp liblua.* ${current}/

cd ${current} && rm -rf build
