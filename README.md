# core_framework
A Web light-framework for Lua based Libev

---

## 安装要求

>  支持的操作系统 

    1. linux (most of)

    2. BSD (most of)

    3. Mac OSX

> 依赖库

    1. libev

    2. ssl(openssl/libressl)

    3. jemalloc(optional, 注释掉makefile相关宏即可去除)

    4. lua

## 编译方式

> 编译(Only)

    1. Make build

> 重新编译(Clean And Build)

    2. make rebuild

## 运行

    bash#: ./main
    
    
## 遇到的问题

    Q1. linux下链接lua出错

        A. 请重新编译并且使用make linux MYCFLAGS=-fPIC宏.

    Q2. 运行的时候提示找不到动态链接库。

        A. 请使用export 将/usr/local/lib导入到LD_LIBRARY_PATH内

    Q3. 其它错误

        A. 请提issue知会作者

# LICENSE

[BSD LICENSE](https://github.com/CandyMi/core_framework/blob/dev/LICENSE)
