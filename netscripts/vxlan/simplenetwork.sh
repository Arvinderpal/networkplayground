#!/bin/bash
set -ex

# /vagrant/netscripts/vxlan/simplenetwork.sh 10.1.1. 10.1.1.0/24 192.168.70.201

# the script is generally called by Vagrantfile to setup default networks

CMD_PATH="/vagrant/netscripts/vxlan/"
IP_PREFIX=$1 # e.g. 10.1.2.
HOST_SUBNET=$2 # e.g. 10.1.1.0/24
BOX_IP=$3 # e.g. 192.168.70.201

#  for a unique port number, we remove the '.' from the ip address
$CMD_PATH/addnetns.sh ns1 $IP_PREFIX"2" ${IP_PREFIX//.}"2" 100 $HOST_SUBNET $BOX_IP
# $CMD_PATH/addnetns.sh ns2 $IP_PREFIX"3" ${IP_PREFIX//.}"3" 200 $HOST_SUBNET $BOX_IP