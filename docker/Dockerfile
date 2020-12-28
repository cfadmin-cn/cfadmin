FROM centos:7
MAINTAINER CandyMi "869646063@qq.com"

RUN yum install gcc file autoconf automake make libtool git openssl-devel -y \
  && git clone https://github.com/CandyMi/cfadmin.git /app \
  && cd /app && sh build.sh && make build \
  && rm -rf /var/cache/yum

# 使用者可在启动容器时使用-v命令将您的代码目录直接挂载到/app/script目录进行调试操作
WORKDIR /app

ENTRYPOINT ["./cfadmin"]
