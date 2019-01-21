# core_framework
A Web light-framework for Lua based Libev

---
## 介绍

cf技术点相关整理:

    1. 网络层

        1.1 TCP

        1.2 UDP

    2. 协议

        2.1 DNS

        2.2 Websocket

        2.3 HTTP

        2.4 MQTT

        2.5 MySQL

        2.6 Redis

    3. 工具

        3.1 Timer(定时器)

        3.2 task(异步协程)

        3.3 DB(MySQL封装)

        3.4 Cache(Redis封装)

    4. 测试文件

        script文件夹内

    5. 文档(TODO)

        暂无


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

> 编译(build)

    make build

> 清理(clean)

    make clean

> 重新编译(clean and build)

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

    Q6. 关于使用-d参数后台运行后, 一次读取海量数据(max size > ulimit -s)后可能造成的崩溃(coredump)的情况.

        A. 默认情况下Linux/BSD/Unix/Mac等操作系统的2M(2048)-8M(8192)不等, 可以考虑建议手动修改一下limits.d/launched改为32M(32768).
           请注意: 这不是一个bug! 虽然你90%的情况下不会遇到这个问题, 但是这一点我作为一个问题, 我需要在首页的README中指出!
           作为一个高性能的事件驱动框架, 我需要减少任何可能造成的性能问题与内存碎片产生的可能性.(使用栈内存毫无疑问比使用堆内存分配/释放要更快)
           但是我不会强制大家这也做, 因为cf可能会工作在一个数据量小并且内存极其有限的环境下(32M<=). 并且我已经将内存函数hook为绝不返回NULL.
           至于为什么推崇是32M? 是因为cf引入的一些开源的lualib内部都为16M的数据量大小限制. 而我虽然很容易就可以修改, 但是基于基本的协议标准导致我不想去做这些.

    Q7. 其它错误

        A. 请提issues或者邮箱知会作者

# 联系方式

    1. issues

    2. 869646063@qq.com

# LICENSE

[BSD LICENSE](https://github.com/CandyMi/core_framework/blob/dev/LICENSE)
