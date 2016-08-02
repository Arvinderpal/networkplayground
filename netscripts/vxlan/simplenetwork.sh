#!/bin/bash
set -ex

# /vagrant/netscripts/vxlan/simplenetwork.sh 10.1.1. 10.1.1.0/24 192.168.70.201

# the script is generally called by Vagrantfile to setup default networks

CMD_PATH="/vagrant/netscripts/vxlan/"
HOST_NAME=$1
IP_PREFIX=$2 # e.g. 10.1.2.
HOST_SUBNET=$3 # e.g. 10.1.1.0/24
BOX_IP=$4 # e.g. 192.168.70.201

#  for a unique port number, we remove the '.' from the ip address

VNID1="100"
$CMD_PATH/addnetns.sh ns1 $IP_PREFIX"2" ${IP_PREFIX//.}"2" $VNID1 $HOST_SUBNET $BOX_IP

VNID2="200"
$CMD_PATH/addnetns.sh ns2 $IP_PREFIX"3" ${IP_PREFIX//.}"3" $VNID2 $HOST_SUBNET $BOX_IP


# add rules 

# allow ns1 on host etcd-01 to receive (ingress) traffic from ns1 on host etcd-02. (Same namespace/VNID)
MY_IP="10.1.1.2"
PEER_IP="10.1.2.2"
PROTO="icmp"
PROTO_PORT="12000"
if [[ $HOST_NAME =~ "etcd-01" ]] ; then 
	$CMD_PATH/allow_ingress.sh "to_me" $MY_IP $PEER_IP $PROTO $PROTO_PORT ${MY_IP//.}
fi
# note MY_IP and PEER_IP are switched:
if [[ $HOST_NAME =~ "etcd-02" ]] ; then 
	$CMD_PATH/allow_ingress.sh  "from_peer" $PEER_IP $MY_IP $PROTO $PROTO_PORT ${PEER_IP//.}
fi

