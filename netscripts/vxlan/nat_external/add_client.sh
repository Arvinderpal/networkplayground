#!/bin/bash
set -ex

CMD_PATH="/vagrant/netscripts/vxlan/nat_simple"

# sh /vagrant/netscripts/vxlan/nat_external/add_client.sh c1 192.168.70.200 1000

NAME=$1
POD_IP=$2
POD_PORT=$3

BOX_IP=$6
PEER_PORT=$7

OVS_BRIDGE=ovs-br
intveth="${NAME}-tap"
extveth="ovs-${NAME}-tap"

# delete if it exists 
# ip netns delete $NAME
# ip link del $extveth

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
ip netns exec $NAME ip addr add dev $intveth "${POD_IP}/24"

# the default route 
ip netns exec $NAME ip route add default dev $intveth



# ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
# 	"in_port=${POD_PORT},ip,action=ct(commit,zone=1,nat(src=10.1.1.240-10.1.1.255)),${PEER_PORT}"
# # ARP
# ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
# 	"priority=10 arp action=normal"
# ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
# 	"priority=0,action=drop"