#!/bin/bash
set -ex

CMD_PATH="/vagrant/netscripts/vxlan/"

# sh /vagrant/netscripts/vxlan/addnetns.sh ns1 10.1.1.1 1234 111 10.1.1.0/24
# sh /vagrant/netscripts/vxlan/addnetns.sh ns2 10.1.2.1 1234 111 10.1.2.0/24

CMD="add"
NAME=$1
POD_IP=$2
POD_PORT=$3
VNID=$4
HOSTSUBNET=$5 # e.g. 10.1.5.0/24

OVS_BRIDGE=ovs-br
intveth="${NAME}-tap"
extveth="ovs-${NAME}-tap"

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

# let's setup all the flow rules
$CMD_PATH/ovsv1.sh $CMD $NAME $POD_IP $POD_PORT $VNID $HOSTSUBNET
