#!/bin/bash

if [[ "$USER" != "root" ]]; then
  echo "script must run as root"
  exit 1
fi

set -eux

export DEBIAN_FRONTEND=noninteractive

#apt-get install -y bcc-tools libbcc-examples

apt-key adv --keyserver keyserver.ubuntu.com --recv-keys D4284CDD
echo "deb https://repo.iovisor.org/apt trusty main" | sudo tee /etc/apt/sources.list.d/iovisor.list
apt-get update
apt-get install -y binutils bcc bcc-tools libbcc-examples python-bcc

# llvm and clang-3.8:
# http://apt.llvm.org/
# NOTE: not all packages installed, see other instructions:
wget -O - http://apt.llvm.org/llvm-snapshot.gpg.key|sudo apt-key add -
apt-get install -y git clang-3.8 lldb-3.8 
apt install -y linux-tools-common linux-tools-generic linux-cloud-tools-generic
# this seems necessary on ubuntu for llvm/clang
apt-get install -y libc6-dev-i386
apt-get install -y bison flex libdb-dev
# these are for the linux/samples/bcc
apt-get install -y bc libssl-dev elfutils libelf-dev 
cd /usr/bin
ln -s ../lib/llvm-3.8/bin/llc llc
ln -s ../lib/llvm-3.8/bin/clang clang

# install kernel sources 
# VAGRANT_MOUNT_DIR=/vagrant/
VAGRANT_MOUNT_DIR=/root/go/src/github.com/networkplayground
KERNEL_VERSION=linux-4.9-rc5
KERNEL_SRC_TAR=linux-4.9-rc5.tar.gz
KERNEL_SRC_BASE_DIR=/home/vagrant/linux/
mkdir -p $KERNEL_SRC_BASE_DIR
cd $KERNEL_SRC_BASE_DIR
cp $VAGRANT_MOUNT_DIR/netscripts/kernel/src/$KERNEL_SRC_TAR .
tar -xf $KERNEL_SRC_TAR
cd $KERNEL_VERSION
make olddefconfig
make headers_install
make samples/bpf/

# install iproute2
cd ~
git clone git://git.kernel.org/pub/scm/linux/kernel/git/shemminger/iproute2.git
cd iproute2/
export HAVE_ELF=y
make
make install

# tunnel demo
apt-get install -y npm
# from cilium:
apt-get -y install socat curl jq realpath pv 