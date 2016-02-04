#!/bin/bash

# install curl if needed
if [[ ! -e /usr/bin/curl ]]; then
  apt-get update
  apt-get -yqq install curl
fi

#########################
# etcd install and setup
#########################

if [[ ! -e /usr/local/bin/etcd ]]; then
  # Get etcd download
  curl -sL  https://github.com/coreos/etcd/releases/download/v2.0.9/etcd-v2.0.9-linux-amd64.tar.gz -o etcd-v2.0.9-linux-amd64.tar.gz

  # Expand the download
  tar xzvf etcd-v2.0.9-linux-amd64.tar.gz

  # Move etcd and etcdctl to /usr/local/bin
  cd etcd-v2.0.9-linux-amd64
  sudo mv etcd /usr/local/bin/
  sudo mv etcdctl /usr/local/bin/
  cd ..

  # Remove etcd download and directory
  rm etcd-v2.0.9-linux-amd64.tar.gz
  rm -rf etcd-v2.0.9-linux-amd64

  # Create directories needed by etcd
  sudo mkdir -p /var/etcd
fi

# Copy files into the correct locations; requires shared folders
sudo cp /vagrant/etcd.conf /etc/init/etcd.conf
sudo cp /vagrant/$HOSTNAME.defaults /etc/default/etcd

# restart if already running, otherwise start.
initctl status etcd && initctl restart etcd || initctl start etcd

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
sudo apt-get update

# Install LXC/LXD if not already installed
if [[ ! -e /usr/bin/lxd ]]; then
    sudo apt-get -y install lxd
fi

#################
# Misc Packages
#################
apt-get install -q -y iperf netperf 
apt-get install -q -y openvswitch-switch openvswitch-ipsec
apt-get install -q -y ipsec-tools racoon
