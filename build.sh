#!/usr/bin/env bash

# Run this file to install libev and lua; if you already have lua and libev in your environment, you can ignore this file and try to compile directly using makefile.
# 运行这个文件可以安装libev与lua; 如果您的环境中已经有了lua/libeio/libev后可以忽略此文件并且直接使用makefile尝试编译.

# This file must be executed in the current folder directory, otherwise the installation will be wrong. Beginners need to keep in mind.
# 必须在当前文件夹目录执行此文件, 否则安装将会出错. 初学者需要谨记.

# Running this script in some embedded environments may lack the scripting tools that should be present (eg ls/printf/grep, etc.), you should find a way to install this command.
# 在一些嵌入式环境下运行此脚本可能会缺少本应存在的脚本工具(如: ls/printf/grep等等), 您应该想办法安装此命令.

# Before executing this build file, you need to make sure that these software environments are installed: gcc/clang autoconf automake make libtool git readline-devel openssl-devel.
# 执行这个编译文件之前需要确保安装了这些软件环境: gcc/clang autoconf automake make libtool git readline-devel openssl-devel. 如果未安装或者缺少安装, 请仔细检查并且自行尝试安装依赖环境.

current=`pwd`

rm -rf build && mkdir build && cd build


osID=`cat /etc/*-release | grep -w ID | cut -f2 -d '='`


timeArea=`date +"%Z %z"`
if [[ $timeArea == "CST +0800" ]] 
then
    echo -n "是否自动安装cfadmin所需依赖? y/n: "
else
    echo -n "Do you want to install the required dependencies? (y/N)? y/n: "
fi

#自动安装依赖
read isAutoDependence 
if [[ $isAutoDependence == "y" ]] || [[ $isAutoDependence == "yes" ]] 
then
    if [[ $osID == "debian" ]] || [[ $osID == "ubuntu" ]] ||  [[ $osID == "kali" ]] ||  [[ $osID == "linuxmint" ]]  ||  [[ $osID == "pop" ]]  ||  [[ $osID == "mx" ]] ||  [[ $osID == "deepin" ]]
    then
        if [ `id -u` -ne 0 ]; then
            sudo apt install gcc file autoconf automake make libtool git libssl-dev zlib1g-dev --no-upgrade
        else
            apt install gcc file autoconf automake make libtool git libssl-dev zlib1g-dev --no-upgrade
        fi
    elif [[ $osID == "centos" ]] ||  [[ $osID == "rhel" ]] || [[ $osID == "suse"  ]] || [[ $osID == "rocky"  ]] || [[ $osID == "ol"  ]] || [[ $osID == "scientific"  ]]  || [[ $osID == "almalinux"  ]] 
    then
        if [ `id -u` -ne 0 ]; then
            sudo yum install gcc file autoconf automake make libtool git zlib-devel openssl-devel -y
        else
            yum install gcc file autoconf automake make libtool git zlib-devel openssl-devel -y
        fi
    elif [[ $osID == "arch" ]] ||  [[ $osID == "msys2" ]]  || [[ $osID == "artix" ]] || [[ $osID == "manjaro"  ]] || [[ $osID == "endeavouros"  ]] || [[ $osID == "parabola"  ]]  || [[ $osID == "archbang"  ]]
    then
        if [ `id -u` -ne 0 ]; then
            sudo pacman -S gcc file autoconf automake make libtool git zlib-devel openssl-devel
        else
            pacman -S gcc file autoconf automake make libtool git zlib-devel openssl-devel
        fi
    else
        echo $osID "not support anto install dependence, please request issue. https://github.com/cfadmin-cn/cfadmin"
    fi
else
    echo "not auto install dependence"
fi

# 通过时区,自动选择镜像源
if [[ $timeArea == "CST +0800" ]] 
then 
  git clone https://gitee.com/CandyMi/lua -b v5.4.3
  git clone https://gitee.com/CandyMi/libev -b v4.33
  git clone https://gitee.com/CandyMi/libeio

else 
  git clone https://github.com/CandyMi/lua -b v5.4.3
  git clone https://github.com/CandyMi/libev -b v4.33
  git clone https://github.com/CandyMi/libeio
fi

echo "========== build libev ==========" &&
  cd ${current}/build/libev && sh autogen.sh && ./configure --prefix=/usr/local --enable-shared=no --with-pic &&

  ## 1. 将头文件与库文件放到cf框架目录下（Put the header files and library files in the cf framework directory）
  make && cp e*.h ${current}/src && cd .libs && cp $(printf "%s" "`ls | grep libev | grep -v la`") ${current}/

  ## 2. 将 libev 安装到 /usr/local 区域, 对其进行全局共享库链接. (Install `libev` into the `/usr/local` zone and link it with global shared libraries.)
  # make && make install

echo "========== build libeio ==========" &&
  cd ${current}/build/libeio && sh autogen.sh && ./configure --prefix=/usr/local --enable-shared=no --with-pic &&

  ## 1. 将头文件与库文件放到cf框架目录下（Put the header files and library files in the cf framework directory）
  make && cp e*.h ${current}/src && cd .libs && cp $(printf "%s" "`ls | grep libeio | grep -v la`") ${current}/

  ## 2. 将 libeio 安装到 /usr/local 区域, 对其进行全局共享库链接. (Install `libeio` into the `/usr/local` zone and link it with global shared libraries.)
  # make && make install

echo "========== build lua ==========" &&
    cd ${current}/build/lua && make posix MYCFLAGS="-fPIC -DLUA_USE_DLOPEN" MYLIBS="-ldl" &&

    ## 1. 将头文件与库文件放到cf框架目录下（Put the header files and library files in the cf framework directory）
    cp lua.h luaconf.h lualib.h lauxlib.h ${current}/src && cp liblua.* ${current}/

    ## 2. 将 lua 安装到 /usr/local 区域, 对其进行全局共享库链接. (Install `lua` into the `/usr/local` zone and link it with global shared libraries.)
    # cp -rf lua.h luaconf.h lualib.h lauxlib.h /usr/local/include && cp liblua.* /usr/local/lib

echo "Done."

echo "========== clean build ==========" && cd ${current} && rm -rf build
