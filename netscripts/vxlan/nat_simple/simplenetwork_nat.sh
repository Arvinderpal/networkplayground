#!/bin/bash
set -ex

# sh /vagrant/netscripts/vxlan/nat_simple/simplenetwork_nat.sh 10.1.9. 10.1.9.0/24 192.168.70.201
# the script is generally called by Vagrantfile to setup default networks

OVS_BRIDGE=ovs-br

CMD_PATH="/vagrant/netscripts/vxlan/nat_simple"
IP_PREFIX=$1 # e.g. 10.1.2.
HOST_SUBNET=$2 # e.g. 10.1.1.0/24
BOX_IP=$3 # e.g. 192.168.70.201

CLIENT_PORT="100"
SERVER_PORT="200"


# create the switch
# fail-mode=secure won't put the default "normal" rule in table-0
ovs-vsctl --may-exist add-br $OVS_BRIDGE -- set Bridge $OVS_BRIDGE fail-mode=secure


#  for a unique port number, we remove the '.' from the ip address
$CMD_PATH/add_client.sh c1 $IP_PREFIX"1" $CLIENT_PORT $CLIENT_PORT $HOST_SUBNET $BOX_IP $SERVER_PORT
$CMD_PATH/add_server.sh s1 $IP_PREFIX"2" $SERVER_PORT $SERVER_PORT $HOST_SUBNET $BOX_IP $CLIENT_PORT