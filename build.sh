#!/bin/bash
# 运行这个文件可以安装libev与lua

current=`pwd`

rm -rf build && mkdir build && cd build

git clone https://github.com/CandyMi/lua -b v5.3.5
git clone https://github.com/CandyMi/libev -b v4.25

cd ${current}/build/libev &&
  sh autogen.sh && ./configure --prefix=/usr/local &&
  make && cp ev*.h ${current}/src && cp .libs/libev* ${current}/

cd ${current}/build/lua &&
  make all MYCFLAGS=-fPIC MYCFLAGS+=-DLUA_USE_POSIX MYCFLAGS+=-DLUA_USE_DLOPEN MYLIBS="-ldl -lreadline" &&
  cp lua.h luaconf.h lualib.h lauxlib.h ${current}/src && cp liblua.* ${current}/

cd ${current} && rm -rf build
