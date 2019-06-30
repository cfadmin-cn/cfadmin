FROM centos:7
MAINTAINER CandyMi "869646063@qq.com"

WORKDIR /root/download

RUN rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7 \
	&& yum install nc gcc file vim autoconf automake make libtool git readline-devel openssl-devel -y \
	&& rm -rf /roo/download /var/cache/yum \
	&& git clone https://github.com/CandyMi/core_framework /app \
	&& cd /app && sh build.sh && make build

# 使用者可在启动容器时使用-v命令将您的代码目录直接挂载到/app/script目录进行调试操作
WORKDIR /app

ENTRYPOINT ["./cfadmin"]
