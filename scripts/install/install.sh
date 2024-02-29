#!/usr/bin/env bash

# Copyright 2020 Lingfei Kong <colin404@foxmail.com>. All rights reserved.
# Use of this source code is governed by a MIT style
# license that can be found in the LICENSE file.


# The root of the build/dist directory
IAM_ROOT=$(dirname "${BASH_SOURCE[0]}")/../..
source "${IAM_ROOT}/scripts/install/common.sh"

source ${IAM_ROOT}/scripts/install/mariadb.sh
source ${IAM_ROOT}/scripts/install/redis.sh
source ${IAM_ROOT}/scripts/install/mongodb.sh
source ${IAM_ROOT}/scripts/install/iam-apiserver.sh
source ${IAM_ROOT}/scripts/install/iam-authz-server.sh
source ${IAM_ROOT}/scripts/install/iam-pump.sh
source ${IAM_ROOT}/scripts/install/iam-watcher.sh
source ${IAM_ROOT}/scripts/install/iamctl.sh
source ${IAM_ROOT}/scripts/install/man.sh
source ${IAM_ROOT}/scripts/install/test.sh

# 申请服务器，登录 going 用户后，配置 $HOME/.bashrc 文件
iam::install::prepare_linux()
{
  # 2. 配置 $HOME/.bashrc
  cat << 'EOF' > $HOME/.bashrc
# .bashrc

# User specific aliases and functions

alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

if [ ! -d $HOME/workspace ]; then
    mkdir -p $HOME/workspace
fi

# User specific environment
# Basic envs
export LANG="en_US.UTF-8" # 设置系统语言为 en_US.UTF-8，避免终端出现中文乱码
export PS1='[\u@dev \W]\$ ' # 默认的 PS1 设置会展示全部的路径，为了防止过长，这里只展示："用户名@dev 最后的目录名"
export WORKSPACE="$HOME/workspace" # 设置工作目录
export PATH=$HOME/bin:$PATH # 将 $HOME/bin 目录加入到 PATH 变量中

# Default entry folder
cd $WORKSPACE # 登录系统，默认进入 workspace 目录

# User specific aliases and functions
EOF

  # 3. 安装依赖包
  iam::common::sudo "dnf -y install make autoconf automake cmake perl-CPAN libcurl-devel libtool gcc gcc-c++ glibc-headers zlib-devel git-lfs telnet lrzsz jq expat-devel openssl-devel git go protobuf man"

  # 5. 配置 Git
  git config --global user.name "Lingfei Kong"    # 用户名改成自己的
  git config --global user.email "colin404@foxmail.com"    # 邮箱改成自己的
  git config --global credential.helper store    # 设置 Git，保存用户名和密码
  git config --global core.longpaths true # 解决 Git 中 'Filename too long' 的错误
  git config --global core.quotepath off
  git lfs install --skip-repo
  source $HOME/.bashrc
  iam::log::info "prepare linux basic environment successfully"
}

# 初始化新申请的 Linux 服务器，使其成为一个友好的开发机
function iam::install::init_into_go_env()
{
  # 1. Linux 服务器基本配置
  iam::install::prepare_linux || return 1

  # 2. Go 编译环境安装和配置
  iam::install::go || return 1

  # 3. Go 开发 IDE 安装和配置
  iam::install::vim_ide || return 1

  iam::log::info "initialize linux to go development machine  successfully"
}

# Go 编译环境安装和配置
function iam::install::go_command()
{
  # 3. 配置 Go 环境变量
  cat << 'EOF' >> $HOME/.bashrc
# Go envs
export GO111MODULE="on" # 开启 Go moudles 特性
export GOPROXY=https://goproxy.cn,direct # 安装 Go 模块时，代理服务器设置
export GOPRIVATE=
export GOSUMDB=off # 关闭校验 Go 依赖包的哈希值
EOF
  source $HOME/.bashrc
  iam::log::info "install go compile tool successfully"
}

function iam::install::protobuf()
{
  # 2. 安装 protoc-gen-go
  go install github.com/golang/protobuf/protoc-gen-go@v1.5.2

  iam::log::info "install protoc-gen-go plugin successfully"
}

function iam::install::go()
{
  iam::install::go_command || return 1
  iam::install::protobuf || return 1

  iam::log::info "install go develop environment successfully"
}

function iam::install::vim_ide()
{
  rm -rf $HOME/.vim $HOME/.vimrc /tmp/gotools-for-vim.tgz # clean up

  # 1. 安装 vim-go
  mkdir -p ~/.vim/pack/plugins/start
  git clone --depth=1 https://github.com/fatih/vim-go.git $HOME/.vim/pack/plugins/start/vim-go
  cp "${IAM_ROOT}/scripts/install/vimrc" $HOME/.vimrc

  # 2. Go 工具安装
  wget -P /tmp/ https://marmotedu-1254073058.cos.ap-beijing.myqcloud.com/tools/gotools-for-vim.tgz && {
    mkdir -p $GOPATH/bin
    tar -xvzf /tmp/gotools-for-vim.tgz -C $GOPATH/bin
  }

  source $HOME/.bashrc
  iam::log::info "install vim ide successfully"
}

function iam::install::prepare_iam()
{
   go work use /iam
  # NOTICE: 因为切换编译路径，所以这里要重新赋值 IAM_ROOT 和 LOCAL_OUTPUT_ROOT
  # IAM_ROOT=$WORKSPACE/golang/src/github.com/marmotedu/iam

  IAM_ROOT=/iam
  LOCAL_OUTPUT_ROOT="${IAM_ROOT}/${OUT_DIR:-_output}"

  pushd ${IAM_ROOT}

  # 2. 配置 $HOME/.bashrc 添加一些便捷入口
  if ! grep -q 'Alias for quick access' $HOME/.bashrc;then
    cat << 'EOF' >> $HOME/.bashrc
# Alias for quick access
#export GOSRC="$WORKSPACE/golang/src"
export IAM_ROOT="/iam"
#alias mm="cd $GOSRC/github.com/marmotedu"
alias i="cd /iam"
EOF
  fi

  # 3. 初始化 MariaDB 数据库，创建 iam 数据库

  # 3.1 登录数据库并创建 iam 用户
  #这条命令是用于授权的，它允许用户`${MARIADB_USERNAME}`在本地主机（127.0.0.1）上访问`iam`数据库的所有权限，
  # 并使用密码`${MARIADB_PASSWORD}`进行身份验证。
#  grant all on iam.* TO ${MARIADB_USERNAME}@127.0.0.1 identified by "${MARIADB_PASSWORD}";
  mysql -h127.0.0.1 -P3306 -u"${MARIADB_ADMIN_USERNAME}" -p"${MARIADB_ADMIN_PASSWORD}" << EOF
grant all on iam.* TO ${MARIADB_USERNAME}@0.0.0.0 identified by "${MARIADB_PASSWORD}";
flush privileges;
EOF

  # 3.2 用 iam 用户登录 mysql，执行 iam.sql 文件，创建 iam 数据库
  mysql -h127.0.0.1 -P3306 -u${MARIADB_USERNAME} -p"${MARIADB_PASSWORD}" << EOF
source configs/iam.sql;
show databases;
EOF

  # 4. 创建必要的目录
  echo ${LINUX_PASSWORD} | sudo -S mkdir -p ${IAM_DATA_DIR}/{iam-apiserver,iam-authz-server,iam-pump,iam-watcher}
  iam::common::sudo "mkdir -p ${IAM_INSTALL_DIR}/bin"
  iam::common::sudo "mkdir -p ${IAM_CONFIG_DIR}/cert"
  iam::common::sudo "mkdir -p ${IAM_LOG_DIR}"

  # 5. 安装 cfssl 工具集
  ! command -v cfssl &>/dev/null || ! command -v cfssl-certinfo &>/dev/null || ! command -v cfssljson &>/dev/null && {
    iam::install::install_cfssl || return 1
  }

  # 6. 配置 hosts
  if ! egrep -q 'iam.*marmotedu.com' /etc/hosts;then
    echo ${LINUX_PASSWORD} | sudo -S bash -c "cat << 'EOF' >> /etc/hosts
    127.0.0.1 iam.api.marmotedu.com
    127.0.0.1 iam.authz.marmotedu.com
    EOF"
  fi

  iam::log::info "prepare for iam installation successfully"
  popd
}

function iam::install::unprepare_iam()
{
  pushd ${IAM_ROOT}

  # 1. 删除 iam 数据库和用户
  mysql -h127.0.0.1 -P3306 -u"${MARIADB_ADMIN_USERNAME}" -p"${MARIADB_ADMIN_PASSWORD}" << EOF
drop database iam;
drop user ${MARIADB_USERNAME}@127.0.0.1
EOF

  # 2. 删除创建的目录
  iam::common::sudo "rm -rf ${IAM_DATA_DIR}"
  iam::common::sudo "rm -rf ${IAM_INSTALL_DIR}"
  iam::common::sudo "rm -rf ${IAM_CONFIG_DIR}"
  iam::common::sudo "rm -rf ${IAM_LOG_DIR}"

  # 3. 删除配置 hosts
  echo ${LINUX_PASSWORD} | sudo -S sed -i '/iam.api.marmotedu.com/d' /etc/hosts
  echo ${LINUX_PASSWORD} | sudo -S sed -i '/iam.authz.marmotedu.com/d' /etc/hosts

  iam::log::info "unprepare for iam installation successfully"
  popd
}

function iam::install::install_cfssl()
{
  mkdir -p $HOME/bin/
#  wget https://github.com/cloudflare/cfssl/releases/download/v1.6.1/cfssl_1.6.1_linux_amd64 -O $HOME/bin/cfssl
#  wget https://github.com/cloudflare/cfssl/releases/download/v1.6.1/cfssljson_1.6.1_linux_amd64 -O $HOME/bin/cfssljson
#  wget https://github.com/cloudflare/cfssl/releases/download/v1.6.1/cfssl-certinfo_1.6.1_linux_amd64 -O $HOME/bin/cfssl-certinfo
  mv /iam/cfssl/* $HOME/bin/
  chmod +x $HOME/bin/{cfssl,cfssljson,cfssl-certinfo}
  iam::log::info "install cfssl tools successfully"
}

function iam::install::install_storage()
{
  iam::mariadb::install || return 1
  iam::redis::install || return 1
  iam::mongodb::install || return 1
  iam::log::info "install storage successfully"
}

function iam::install::uninstall_storage()
{
  iam::mariadb::uninstall || return 1
  iam::redis::uninstall || return 1
  iam::mongodb::uninstall || return 1
  iam::log::info "uninstall storage successfully"
}

# 安装 IAM 应用
function iam::install::install_iam()
{
  # 1. 安装并初始化数据库
  iam::install::install_storage || return 1

  # 2. 先准备安装环境
  iam::install::prepare_iam || return 1

  # 3. 安装 iam-apiserver 服务
  iam::apiserver::install || return 1

  # 4. 安装 iamctl 客户端工具
  iam::iamctl::install || return 1

  # 5. 安装 iam-authz-server 服务
  iam::authzserver::install || return 1

  # 6. 安装 iam-pump 服务
  iam::pump::install || return 1

  # 7. 安装 iam-watcher 服务
  iam::watcher::install || return 1

  # 8. 安装 man page
  iam::man::install || return 1
  source $HOME/.bashrc
  iam::log::info "install iam application successfully"
}

function iam::install::uninstall_iam()
{
  iam::man::uninstall || return 1
  iam::iamctl::uninstall || return 1
  iam::pump::uninstall || return 1
  iam::watcher::uninstall || return 1
  iam::authzserver::uninstall || return 1
  iam::apiserver::uninstall || return 1

  iam::install::unprepare_iam || return 1

  iam::install::uninstall_storage|| return 1
}

function iam::install::init_into_vim_env(){
  # 1. Linux 服务器基本配置
  iam::install::prepare_linux || return 1

  # 2. Go 开发 IDE 安装和配置
  iam::install::vim_ide || return 1

  iam::log::info "initialize linux with SpaceVim successfully"
}

function iam::install::install()
{
  # 1. 配置 Linux 使其成为一个友好的 Go 开发机
  iam::install::init_into_go_env || return 1

  # 2. 安装 IAM 应用
  iam::install::install_iam || return 1

  # 3. 测试安装后的 IAM 系统功能是否正常
  iam::test::test || return 1

  iam::log::info "$(echo -e '\033[32mcongratulations, install iam application successfully!\033[0m')"
}

# 卸载。卸载只卸载服务，不卸载环境，不会卸载列表如下：
# - 配置的 $HOME/.bashrc
# - 安装和配置的 Go 编译环境和工具：go、protoc、protoc-gen-go
# - 安装的依赖包
# - 安装的工具：cfssl 工具
# - 下载的 iam 源码包及其目录
# - 安装的 neovim 和 SpaceVim
#
# 也即只卸载 IAM 应用部分，卸载后，Linux 仍然是一个友好的 Go 开发机
function iam::install::uninstall()
{
  iam::install::uninstall_iam || return 1
  iam::log::info "uninstall iam application successfully"
}

eval $*
