FROM rockylinux/rockylinux:9 as builder
# 设置时区与语言环境变量
#ENV TIME_ZONE=Asia/Shanghai
#RUN echo "${TIME_ZONE}" > /etc/timezone && ln -sf /usr/share/zoneinfo/${TIME_ZONE} /etc/localtime
WORKDIR /app

ADD . /app
RUN yum install gcc file autoconf automake make libtool git openssl-devel zlib-devel -y && rm -rf /var/cache/yum
RUN  sh build.sh && make build 

FROM rockylinux/rockylinux:9
# 设置时区与语言环境变量
#ENV TIME_ZONE=Asia/Shanghai
#RUN echo "${TIME_ZONE}" > /etc/timezone && ln -sf /usr/share/zoneinfo/${TIME_ZONE} /etc/localtime
COPY --from=builder /app/ /app
WORKDIR /app
ENTRYPOINT ["./cfadmin"]
