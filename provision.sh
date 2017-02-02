#!/bin/bash

# install curl if needed
if [[ ! -e /usr/bin/curl ]]; then
  apt-get update
  apt-get -yqq install curl
fi

#########################
# etcd install and setup
#########################

# if [[ ! -e /usr/local/bin/etcd ]]; then
#   # Get etcd download
#   curl -sL  https://github.com/coreos/etcd/releases/download/v2.0.9/etcd-v2.0.9-linux-amd64.tar.gz -o etcd-v2.0.9-linux-amd64.tar.gz

#   # Expand the download
#   tar xzvf etcd-v2.0.9-linux-amd64.tar.gz

#   # Move etcd and etcdctl to /usr/local/bin
#   cd etcd-v2.0.9-linux-amd64
#   sudo mv etcd /usr/local/bin/
#   sudo mv etcdctl /usr/local/bin/
#   cd ..

#   # Remove etcd download and directory
#   rm etcd-v2.0.9-linux-amd64.tar.gz
#   rm -rf etcd-v2.0.9-linux-amd64

#   # Create directories needed by etcd
#   sudo mkdir -p /var/etcd
# fi

# # Copy files into the correct locations; requires shared folders
# sudo cp /vagrant/etcd.conf /etc/init/etcd.conf
# sudo cp /vagrant/$HOSTNAME.defaults /etc/default/etcd

# # restart if already running, otherwise start.
# initctl status etcd && initctl restart etcd || initctl start etcd

#################
# LXD install
#################

# Initial housekeepting
export DEBIAN_FRONTEND=noninteractive

# Add the PPA repository for LXD/LXC stable
if [[ ! -e /etc/apt/sources.list.d/ubuntu-lxc-lxd-stable-trusty.list ]]; then
    sudo add-apt-repository -y ppa:ubuntu-lxc/lxd-stable
fi

# Update package list
# sudo apt-get update
# Install LXC/LXD if not already installed
# if [[ ! -e /usr/bin/lxd ]]; then
#     sudo apt-get -y install lxd
# fi

# #######
# Docker
# #######
apt-get install -y apt-transport-https ca-certificates
curl -fsSL https://yum.dockerproject.org/gpg | sudo apt-key add -
sudo add-apt-repository \
       "deb https://apt.dockerproject.org/repo/ \
       ubuntu-$(lsb_release -cs) \
       main"
apt-get update
apt-get -y install docker-engine

# ####
# GO
# #####
wget https://storage.googleapis.com/golang/go1.7.5.linux-amd64.tar.gz
tar -C /usr/local -xzf go1.7.5.linux-amd64.tar.gz
ln -s  /usr/local/go/bin/go /usr/bin/go
ln -s  /usr/local/go/bin/gofmt /usr/bin/gofmt
ln -s  /usr/local/go/bin/godoc /usr/bin/godoc
# apt-get install -y golang

# #######
# Docker: https://docs.docker.com/engine/installation/linux/ubuntulinux/#/install-the-latest-version
deb https://apt.dockerproject.org/repo ubuntu-xenial main
apt-key adv --keyserver hkp://ha.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
echo "deb https://apt.dockerproject.org/repo ubuntu-xenial main" | sudo tee etc/apt/sources.list.d/docker.list
 # apt-get install -y linux-image-extra-$(uname -r) linux-image-extra-virtual
apt-get install -y docker-engine
service docker start
 
#################
# Misc Packages
#################
apt-get install -q -y dkms libpython-stdlib python python-minimal python-six python-doc python-tk
apt-get install -q -y iperf netperf conntrack

# apt-get install -q -y ipsec-tools racoon

# apt-get install -q -y openvswitch-switch openvswitch-ipsec

# NOTE: /vagrant will need to be changed if mount point for rsync is changed in Vagrantfile
# VAGRANT_MOUNT_DIR=/vagrant/
# VAGRANT_MOUNT_DIR=/root/go/src/github.com/networkplayground
# dpkg -i $VAGRANT_MOUNT_DIR/openvswitch/2.6/openvswitch-common_2.6.0-1_amd64.deb $VAGRANT_MOUNT_DIR/openvswitch/2.6/openvswitch-switch_2.6.0-1_amd64.deb
# apt-get install -q -y dkms
# dpkg -i $VAGRANT_MOUNT_DIR/openvswitch/2.6/openvswitch-datapath-dkms_2.6.0-1_all.deb
