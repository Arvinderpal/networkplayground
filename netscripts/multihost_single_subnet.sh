#!/bin/bash

NETNS_IP=$1
REMOTE1=$2
REMOTE2=$3
TUN_IF1="greiface_"$REMOTE1
TUN_IF2="greiface_"$REMOTE2
OVS_BRIDGE=ovs-test
TUN_TYPE='gre'

echo $NETNS_IP
echo $REMOTE1
echo $REMOTE2
echo $TUN_IF1
echo $TUN_IF2

# create the switch
ovs-vsctl add-br $OVS_BRIDGE
# enable STP
ovs-vsctl set bridge $OVS_BRIDGE stp_enable=true
#
#### PORT 1
# add the namespaces
ip netns add ns1
# create a port pair
ip link add tap1 type veth peer name ovs-tap1
# attach one side to ovs
ovs-vsctl add-port $OVS_BRIDGE ovs-tap1 
# attach the other side to namespace
ip link set tap1 netns ns1
# set the ports to up
ip netns exec ns1 ip link set dev tap1 up
ip link set dev ovs-tap1 up
# Assign IP address
ip netns exec ns1 ip addr add dev tap1 $NETNS_IP
# Create tunnels to remote nodes
ovs-vsctl add-port $OVS_BRIDGE $TUN_IF1 -- set interface $TUN_IF1 type=gre options:remote_ip=$REMOTE1
ovs-vsctl add-port $OVS_BRIDGE $TUN_IF2 -- set interface $TUN_IF2 type=gre options:remote_ip=$REMOTE2
