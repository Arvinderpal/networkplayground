#!/bin/bash

NETNS1_IP=$1
NETNS2_IP=$2
REMOTE1=$3
REMOTE2=$4
TUN_IF1="greiface1_"$REMOTE1
TUN_IF2="greiface2_"$REMOTE2
OVS_BRIDGE=ovs-test
TUN_TYPE='gre'

NETNS1_PORT="4"
NETNS2_PORT="5"

echo $NETNS1_IP
echo $NETNS2_IP
echo $REMOTE1
echo $REMOTE2
echo $TUN_IF1
echo $TUN_IF2

# create the switch
ovs-vsctl add-br $OVS_BRIDGE
# enable STP
ovs-vsctl set bridge $OVS_BRIDGE stp_enable=true
#
#### Subnet1 
# add the namespaces
ip netns add ns1
# create a port pair
ip link add tap1 type veth peer name ovs-tap1
# attach one side to ovs
ovs-vsctl add-port $OVS_BRIDGE ovs-tap1 -- set Interface ovs-tap1 ofport_request=$NETNS1_PORT

# attach the other side to namespace
ip link set tap1 netns ns1
# set the ports to up
ip netns exec ns1 ip link set dev tap1 up
ip link set dev ovs-tap1 up
# Assign IP address
ip netns exec ns1 ip addr add dev tap1 $NETNS1_IP

#### Subnet2
# add the namespaces
ip netns add ns2
# create a port pair
ip link add tap2 type veth peer name ovs-tap2
# attach one side to ovs
ovs-vsctl add-port $OVS_BRIDGE ovs-tap2 -- set Interface ovs-tap2 ofport_request=$NETNS2_PORT

# attach the other side to namespace
ip link set tap2 netns ns2
# set the ports to up
ip netns exec ns2 ip link set dev tap2 up
ip link set dev ovs-tap2 up
# Assign IP address
ip netns exec ns2 ip addr add dev tap2 $NETNS2_IP


# Create tunnels to remote nodes
ovs-vsctl add-port $OVS_BRIDGE $TUN_IF1 -- set interface $TUN_IF1 type=gre options:remote_ip=$REMOTE1 ofport_request=2
ovs-vsctl add-port $OVS_BRIDGE $TUN_IF2 -- set interface $TUN_IF2 type=gre options:remote_ip=$REMOTE2 ofport_request=3

# Filtering rules

# Allow ARP messages
ovs-ofctl add-flow $OVS_BRIDGE priority=200,arp,actions=normal
ovs-ofctl add-flow ovs-test priority=200,arp,in_port=$NETNS1_PORT,nw_dst=$NETNS1_IP,actions=normal
ovs-ofctl add-flow ovs-test priority=200,arp,in_port=$NETNS2_PORT,nw_dst=$NETNS2_IP,actions=normal
# ovs-ofctl add-flow ovs-test arp,in_port=5,nw_dst=10.0.2.1/24,actions=normal

# Allow STP/BPDU packets
ovs-ofctl add-flow $OVS_BRIDGE priority=200,dl_dst=01:80:c2:00:00:00/ff:ff:ff:ff:ff:f0,actions=normal

# SRC IP must what we configured the netns to use
ovs-ofctl add-flow $OVS_BRIDGE priority=100,in_port=$NETNS1_PORT,ip,nw_src=$NETNS1_IP,actions=normal
ovs-ofctl add-flow $OVS_BRIDGE priority=100,in_port=$NETNS2_PORT,ip,nw_src=$NETNS2_IP,actions=normal

# Drop all traffic (lowest priority rule)
ovs-ofctl add-flow $OVS_BRIDGE priority=1,in_port=$NETNS1_PORT,actions=drop
ovs-ofctl add-flow $OVS_BRIDGE priority=1,in_port=$NETNS2_PORT,actions=drop
