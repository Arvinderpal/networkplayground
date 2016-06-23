#!/bin/bash

# NOTES:
# 	1. In this setup, POD1s are all on the same network (vnid=100) and POD2s on VNID=200,
# 		so this means that 10.0.1.1 can ping 10.0.2.1 and 10.0.3.1

export POD1_IP=$1
export POD2_IP=$2
export REMOTETUN1_IP=$3
export REMOTETUN2_IP=$4
export REMOTE1=$5
export REMOTE2=$6

export OVS_BRIDGE=ovs-br
export TUN_TYPE='vxlan'
export VXLAN_PORT="1"
export EXTERNAL_PORT="2"

export POD1_PORT="10"
export POD2_PORT="11"

echo $POD1_IP
echo $POD2_IP
echo $REMOTETUN1_IP
echo $REMOTETUN2_IP
echo $REMOTE1
echo $REMOTE2


# create the switch
ovs-vsctl add-br $OVS_BRIDGE

#
#### Network 100 
VNID_100="100"
# add the namespaces
ip netns add ns1
# create a port pair
ip link add tap1 type veth peer name ovs-tap1
# attach one side to ovs
ovs-vsctl add-port $OVS_BRIDGE ovs-tap1 -- set Interface ovs-tap1 ofport_request=$POD1_PORT

# attach the other side to namespace
ip link set tap1 netns ns1
# set the ports to up
ip netns exec ns1 ip link set dev tap1 up
ip link set dev ovs-tap1 up
# Assign IP address
ip netns exec ns1 ip addr add dev tap1 "${POD1_IP}/16"
# we need /16 because a pod on 10.0.1.* may talk to a pod on 10.0.2.* node

#### Network 200
VNID_200="200"
# add the namespaces
ip netns add ns2
# create a port pair
ip link add tap2 type veth peer name ovs-tap2
# attach one side to ovs
ovs-vsctl add-port $OVS_BRIDGE ovs-tap2 -- set Interface ovs-tap2 ofport_request=$POD2_PORT

# attach the other side to namespace
ip link set tap2 netns ns2
# set the ports to up
ip netns exec ns2 ip link set dev tap2 up
ip link set dev ovs-tap2 up
# Assign IP address
ip netns exec ns2 ip addr add dev tap2 "${POD2_IP}/16"

# Create tunnel 
ovs-vsctl add-port $OVS_BRIDGE vxlan0 -- set interface vxlan0 \
	ofport_request=$VXLAN_PORT \
	type=vxlan \
	options:remote_ip=flow options:key=flow

# EGRESS traffic from pods to remote nodes
# if the packet is from POD1 and is destined for node with subnet REMOTETUN2_IP (e.g. 10.0.2.0/24), 
# then set VNID to 100 and send it to remote1 (which has subnet 10.0.2.0/24)
ovs-ofctl add-flow $OVS_BRIDGE \
	"priority=100,in_port=${POD1_PORT},ip,nw_src=${POD1_IP}/24,nw_dst=${REMOTETUN1_IP} actions=set_tunnel:${VNID_100},set_field:${REMOTE1}->tun_dst,output:${VXLAN_PORT}"
ovs-ofctl add-flow $OVS_BRIDGE \
	"priority=100,in_port=${POD1_PORT},ip,nw_src=${POD1_IP}/24,nw_dst=${REMOTETUN2_IP} actions=set_tunnel:${VNID_100},set_field:${REMOTE2}->tun_dst,output:${VXLAN_PORT}"
# if the packet is from POD2 and is destined for node with subnet REMOTETUN2_IP (e.g. 10.0.2.0/24), 
# then set VNID to 200 and send it to remote1 (which has subnet 10.0.2.0/24)
ovs-ofctl add-flow $OVS_BRIDGE \
	"priority=100,in_port=${POD2_PORT},ip,nw_src=${POD2_IP}/24,nw_dst=${REMOTETUN1_IP} actions=set_tunnel:${VNID_200},set_field:${REMOTE1}->tun_dst,output:${VXLAN_PORT}"
ovs-ofctl add-flow $OVS_BRIDGE \
	"priority=100,in_port=${POD2_PORT},ip,nw_src=${POD2_IP}/24,nw_dst=${REMOTETUN2_IP} actions=set_tunnel:${VNID_200},set_field:${REMOTE2}->tun_dst,output:${VXLAN_PORT}"


# if ARP is from POD1, then set VNID and send across appropriate tunnel
ovs-ofctl add-flow $OVS_BRIDGE \
	"priority=200,in_port=${POD1_PORT},arp,nw_src=${POD1_IP}/24,nw_dst=${REMOTETUN1_IP},actions=set_tunnel:${VNID_100},set_field:${REMOTE1}->tun_dst,output:${VXLAN_PORT}"
ovs-ofctl add-flow $OVS_BRIDGE \
	"priority=200,in_port=${POD1_PORT},arp,nw_src=${POD1_IP}/24,nw_dst=${REMOTETUN2_IP},actions=set_tunnel:${VNID_100},set_field:${REMOTE2}->tun_dst,output:${VXLAN_PORT}"
# Pod2
ovs-ofctl add-flow $OVS_BRIDGE \
	"priority=200,in_port=${POD2_PORT},arp,nw_src=${POD2_IP}/24,nw_dst=${REMOTETUN1_IP},actions=set_tunnel:${VNID_200},set_field:${REMOTE1}->tun_dst,output:${VXLAN_PORT}"
ovs-ofctl add-flow $OVS_BRIDGE \
	"priority=200,in_port=${POD2_PORT},arp,nw_src=${POD2_IP}/24,nw_dst=${REMOTETUN2_IP},actions=set_tunnel:${VNID_200},set_field:${REMOTE2}->tun_dst,output:${VXLAN_PORT}"


# INGRESS traffic from remote nodes to local pods
# if packet arrived on tunnel port from REMOTE1 and has VNID=100 or 200, let's process it as normal
# REMOTE1:
ovs-ofctl add-flow $OVS_BRIDGE \
	"priority=100,in_port=$VXLAN_PORT,tun_src=$REMOTE1,tun_id=$VNID_100,ip,nw_dst=${POD1_IP}/24,actions=output:${POD1_PORT}"
ovs-ofctl add-flow $OVS_BRIDGE \
	"priority=100,in_port=$VXLAN_PORT,tun_src=$REMOTE1,tun_id=$VNID_200,ip,nw_dst=${POD2_IP}/24,actions=output:${POD2_PORT}"
# REMOTE2:
# if packet arrived on tunnel port from REMOTE2 and has VNID=100 or 200, let's process it as normal
ovs-ofctl add-flow $OVS_BRIDGE \
	"priority=100,in_port=$VXLAN_PORT,tun_src=$REMOTE2,tun_id=$VNID_100,ip,nw_dst=${POD1_IP}/24,actions=output:${POD1_PORT}"
ovs-ofctl add-flow $OVS_BRIDGE \
	"priority=100,in_port=$VXLAN_PORT,tun_src=$REMOTE2,tun_id=$VNID_200,ip,nw_dst=${POD2_IP}/24,actions=output:${POD2_PORT}"

# ARP (ingress)
# REMOTE1:
ovs-ofctl add-flow $OVS_BRIDGE \
	"priority=200,in_port=$VXLAN_PORT,tun_src=$REMOTE1,tun_id=$VNID_100,arp,nw_dst=${POD1_IP},actions=output:${POD1_PORT}"
ovs-ofctl add-flow $OVS_BRIDGE \
	"priority=200,in_port=$VXLAN_PORT,tun_src=$REMOTE1,tun_id=$VNID_200,arp,nw_dst=${POD2_IP},actions=output:${POD2_PORT}"
# REMOTE2:
ovs-ofctl add-flow $OVS_BRIDGE \
	"priority=200,in_port=$VXLAN_PORT,tun_src=$REMOTE2,tun_id=$VNID_100,arp,nw_dst=${POD1_IP},actions=output:${POD1_PORT}"
ovs-ofctl add-flow $OVS_BRIDGE \
	"priority=200,in_port=$VXLAN_PORT,tun_src=$REMOTE2,tun_id=$VNID_200,arp,nw_dst=${POD2_IP},actions=output:${POD2_PORT}"


# SRC IP must what we configured the netns to use
# ovs-ofctl add-flow $OVS_BRIDGE priority=100,in_port=$POD1_PORT,ip,nw_src=$POD1_IP,actions=normal
# ovs-ofctl add-flow $OVS_BRIDGE priority=100,in_port=$POD2_PORT,ip,nw_src=$POD2_IP,actions=normal
# Allow ARP messages
# ovs-ofctl add-flow $OVS_BRIDGE priority=150,arp,actions=normal
# ovs-ofctl add-flow $OVS_BRIDGE priority=200,arp,in_port=$POD1_PORT,nw_dst=$POD1_IP,actions=normal
# ovs-ofctl add-flow $OVS_BRIDGE priority=200,arp,in_port=$POD2_PORT,nw_dst=$POD2_IP,actions=normal
# ovs-ofctl add-flow ovs-test arp,in_port=5,nw_dst=10.0.2.1/24,actions=normal

# Drop all traffic (lowest priority rule)
ovs-ofctl add-flow $OVS_BRIDGE priority=1,in_port=$POD1_PORT,actions=drop
ovs-ofctl add-flow $OVS_BRIDGE priority=1,in_port=$POD2_PORT,actions=drop
ovs-ofctl add-flow $OVS_BRIDGE priority=1,in_port=$VXLAN_PORT,actions=drop