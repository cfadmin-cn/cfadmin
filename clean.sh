# This script is used to clean up build.sh to install the header files and library files brought by libev and lua. You can ignore this file when you already have lua and libev in your environment.
# 此脚本为清理build.sh安装libev与lua带来的头文件与库文件, 当您的环境中已经有了lua与libev后可以忽略此文件.

rm -rf libev* libeio* liblua*
rm -rf src/l* src/e*.h
