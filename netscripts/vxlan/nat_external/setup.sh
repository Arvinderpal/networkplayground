#!/bin/bash
set -ex

CMD_PATH="/vagrant/netscripts/vxlan/nat_external"

# sh /vagrant/netscripts/vxlan/nat_external/setup.sh 192.168.70.201

OVS_BRIDGE=ovs-br
EXTERNAL_PORT="2"
HOST_IP=$1

# create the switch
ovs-vsctl --may-exist add-br $OVS_BRIDGE #-- set Bridge $OVS_BRIDGE fail-mode=secure

# add a port for external access
# ovs-vsctl add-port $OVS_BRIDGE ext0 -- set interface ext0 \
# 	type=internal \
# 	ofport_request=$EXTERNAL_PORT \

ifconfig $OVS_BRIDGE $HOST_IP 

ifconfig eth1 0.0.0.0
ovs-vsctl add-port $OVS_BRIDGE eth1

