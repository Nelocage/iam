FROM rockylinux:8.9
RUN sed -e 's|^mirrorlist=|#mirrorlist=|g' \
    -e 's|^#baseurl=http://dl.rockylinux.org/$contentdir|baseurl=https://mirrors.aliyun.com/rockylinux|g' \
    -i.bak \
    /etc/yum.repos.d/Rocky-*.repo
RUN  dnf makecache && dnf update -y &&dnf  -y install vim  sudo wget 
RUN dnf group install -y  "Development Tools"
RUN useradd -ms /bin/bash going
RUN echo 'going:iam59!z$' |chpasswd
RUN sed -i '/^root.*ALL=(ALL).*ALL/a\going\tALL=(ALL) \tALL' /etc/sudoers
ENV LINUX_PASSWORD='iam59!z$'
# RUN version=v1.6.2 && curl https://marmotedu-1254073058.cos.ap-beijing.myqcloud.com/iam-release/${version}/iam.tar.gz | tar -xz -C /tmp/
COPY . /iam 
EXPOSE 3306
EXPOSE 27017
EXPOSE 6379
#docker run -dit  --name  xxx  xx 需要这么执行命令才可以
CMD [ "/bin/bash" ]



