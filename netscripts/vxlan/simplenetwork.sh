#!/bin/bash
set -ex

# sh /vagrant/netscripts/vxlan/addnetns.sh 10.1.1. 10.1.1.0/24
# the script is generally called by Vagrantfile to setup default networks

CMD_PATH="/vagrant/netscripts/vxlan/"
IP_PREFIX=$1 # e.g. 10.1.2.
HOST_SUBNET=$2 # 10.1.1.0/24

#  for a unique port number, we remove the '.' from the ip address
$CMD_PATH/addnetns.sh ns1 $IP_PREFIX"1" ${IP_PREFIX//.}"1" 100 $HOST_SUBNET
$CMD_PATH/addnetns.sh ns2 $IP_PREFIX"2" ${IP_PREFIX//.}"2" 200 $HOST_SUBNET