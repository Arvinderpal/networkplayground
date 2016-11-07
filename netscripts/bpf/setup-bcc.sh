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
