#!/bin/bash


cd /vagrant/openvswitch
dpkg -i openvswitch-common_2.4.0-1_amd64.deb openvswitch-switch_2.4.0-1_amd64.deb python-openvswitch_2.4.0-1_all.deb openvswitch-ipsec_2.4.0-1_amd64.deb

NETNS_IP1=$1
NETNS_IP2=$2
REMOTE1=$3
REMOTE2=$4
TUN_IF1="greipseciface1_"$REMOTE1
TUN_IF2="greipseciface2_"$REMOTE2
OVS_BRIDGE=ovs-test
TUN_TYPE="ipsec_gre"
PSK="thisisnotagoodpsk"

echo $NETNS_IP1
echo $NETNS_IP2
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
ovs-vsctl add-port $OVS_BRIDGE ovs-tap1 
# attach the other side to namespace
ip link set tap1 netns ns1
# Decrease MTU to include GRE+IP headers
ip netns exec ns1 ip link set dev tap1 mtu 1300
# set the ports to up
ip netns exec ns1 ip link set dev tap1 up
ip link set dev ovs-tap1 up
# Assign IP address
ip netns exec ns1 ip addr add dev tap1 $NETNS_IP1

#### Subnet2
# add the namespaces
ip netns add ns2
# create a port pair
ip link add tap2 type veth peer name ovs-tap2
# attach one side to ovs
ovs-vsctl add-port $OVS_BRIDGE ovs-tap2
# attach the other side to namespace
ip link set tap2 netns ns2
# Decrease MTU to include GRE+IP headers
ip netns exec ns2 ip link set dev tap2 mtu 1300
# set the ports to up
ip netns exec ns2 ip link set dev tap2 up
ip link set dev ovs-tap2 up
# Assign IP address
ip netns exec ns2 ip addr add dev tap2 $NETNS_IP2


# ovs-vsctl add-port $OVS_BRIDGE $TUN_IF -- set interface $TUN_IF type=$TUN_TYPE options:remote_ip=$REMOTE_IP options:psk=thisisnotagoodpsk

# Create tunnels to remote nodes
ovs-vsctl add-port $OVS_BRIDGE $TUN_IF1 -- set interface $TUN_IF1 type=$TUN_TYPE options:remote_ip=$REMOTE1 options:psk=$PSK
ovs-vsctl add-port $OVS_BRIDGE $TUN_IF2 -- set interface $TUN_IF2 type=$TUN_TYPE options:remote_ip=$REMOTE2 options:psk=$PSK 
