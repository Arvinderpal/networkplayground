#!/bin/bash

if [[ "$USER" != "root" ]]; then
  echo "script must run as root"
  exit 1
fi

set -eux

export DEBIAN_FRONTEND=noninteractive

# VAGRANT_MOUNT_DIR=/vagrant/
VAGRANT_MOUNT_DIR=/root/go/src/github.com/networkplayground

# download the deb files beforehand from http://kernel.ubuntu.com/~kernel-ppa/mainline/?C=N;O=D
# sudo dpkg -i /vagrant/netscripts/kernel/v4.8.6/*.deb
# sudo dpkg -i /vagrant/netscripts/kernel/v4.7.10/*.deb
sudo dpkg -i $VAGRANT_MOUNT_DIR/netscripts/kernel/v4.9-rc5/*.deb
#apt-get install linux-headers-4.7.0-07282016-torvalds+ linux-image-4.7.0-07282016-torvalds+
