# core_framework
A Web light-framework for Lua based Libev

---

## 安装要求

>  支持的操作系统 

    1. linux (most of)

    2. BSD (most of)

    3. Mac OSX

> 依赖库

    1. libev > 4.24

    2. ssl(openssl/libressl) > 1.0.1

    3. jemalloc/tcmalloc(可选(默认未使用), 建议长期运行的程序手动修改一下相关makefile开启) > 5.0.0

    4. lua > 5.3

## 编译方式

> 编译(Only)

    make build

> 清理(clien)

    make clean

> 重新编译(Clean And Build)

    make rebuild

## 测试运行

    bash#: ./cfadmin

## 后台运行

    bash#: ./cfadmin -d
    
## 已知遇到的问题

    Q1. linux下链接lua出错

        A. 请重新编译并且使用make linux MYCFLAGS=-fPIC宏.

    Q2. 运行的时候提示找不到动态链接库。

        A. 请使用export 将/usr/local/lib导入到LD_LIBRARY_PATH内.

    Q3. linux自己编译的openssl/libressl即使添加到/usr/local/include也提示找不到头文件

        A. 最简单的办法是使用yum/apt等包管理工具安装openssl-devel开发包, 然后尝试重新make rebuild编译;

    Q5. make rebuild/build未报错, 但是提示找不到libcore.so或load libcore.so出错.

        A. 请使用sudo make rebuild/build 增加加权限, 因为libcore.so需要安装到相关目录下.

    Q4. 其它错误

        A. 请提issues或者邮箱知会作者

# 联系方式

    1. issues

    2. 869646063@qq.com

# LICENSE

[BSD LICENSE](https://github.com/CandyMi/core_framework/blob/dev/LICENSE)
