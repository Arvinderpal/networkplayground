#!/bin/bash
set -ex

CMD_PATH="/vagrant/netscripts/vxlan/nat_simple"

# sh /vagrant/netscripts/vxlan/nat_simple/add_client.sh client1 10.1.1.1 1111 111 10.1.1.0/24 5555
# sh /vagrant/netscripts/vxlan/nat_simple/add_server.sh server1 10.1.2.1 5555 111 10.1.2.0/24 1111

CMD="add"
NAME=$1
POD_IP=$2
POD_PORT=$3
VNID=$4
HOSTSUBNET=$5 # e.g. 10.1.5.0/24
BOX_IP=$6
PEER_PORT=$7

OVS_BRIDGE=ovs-br
intveth="${NAME}-tap"
extveth="ovs-${NAME}-tap"

# delete if it exists 
ip netns delete $NAME
# add the namespaces
ip netns add $NAME
# create a port pair
ip link add $intveth type veth peer name $extveth
# attach one side to ovs
ovs-vsctl add-port $OVS_BRIDGE $extveth -- set Interface $extveth ofport_request=$POD_PORT

# attach the other side to namespace
ip link set $intveth netns $NAME
# set the ports to up
ip netns exec $NAME ip link set dev $intveth up
ip link set dev $extveth up
# Assign IP address
ip netns exec $NAME ip addr add dev $intveth "${POD_IP}/16"
# we need /16 because a pod on 10.0.1.* may talk to a pod on 10.0.2.* node

# the default route 
ip netns exec $NAME ip route add default dev $intveth

# let's setup all the flow rules
# $CMD_PATH/ovsv1.sh $CMD $NAME $POD_IP $POD_PORT $VNID $HOSTSUBNET

ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"in_port=${POD_PORT},ip,action=ct(commit,zone=1,nat(src=10.1.1.240-10.1.1.255)),${PEER_PORT}"
# ARP
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"priority=10 arp action=normal"
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"priority=0,action=drop"