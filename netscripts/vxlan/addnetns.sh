#!/bin/bash
set -ex

CMD_PATH="/vagrant/netscripts/vxlan/"

# /vagrant/netscripts/vxlan/addnetns.sh ns1 10.1.1.2 1234 111 10.1.1.0/24
# /vagrant/netscripts/vxlan/addnetns.sh ns2 10.1.2.2 1234 111 10.1.2.0/24

CMD="add"
NAME=$1
POD_IP=$2
POD_PORT=$3
VNID=$4
HOST_SUBNET=$5 # e.g. 10.1.5.0/24

OVS_BRIDGE=ovs-br
intveth="${NAME}-tap"
extveth="ovs-${NAME}-tap"

cleanup(){
list=`ip netns list`
if [[ $list =~ $NAME ]] ; then 
	ip netns delete $NAME
	# ip link delete $extveth
	ovs-vsctl del-port $extveth
	else
		echo $NAME does not exist
	fi
}

cleanup

# add the namespaces
ip netns add $NAME
# create a port pair
ip link add $intveth type veth peer name $extveth
# attach one side to ovs
ovs-vsctl add-port $OVS_BRIDGE $extveth -- set Interface $extveth \
	ofport_request=$POD_PORT 
# type=internal \

# attach the other side to namespace
ip link set $intveth netns $NAME mtu 1200
# set the ports to up
ip netns exec $NAME ip link set dev $intveth up
ip link set dev $extveth up
# Assign IP address
ip netns exec $NAME ip addr add dev $intveth "${POD_IP}/16"
# we need /16 because a pod on 10.0.1.* may talk to a pod on 10.0.2.* node

# the default route 
# ip netns exec $NAME ip route add default dev $intveth
gw_ip=`echo  $HOST_SUBNET | awk -F '.' '{ print $1 "." $2 "." $3 "." 1 }'`
ip netns exec $NAME ip route add default via $gw_ip

# get the mac on inernal veth
POD_MAC=`ip netns exec $NAME ip link show dev $intveth | sed -n -e 's/.*link.ether \([^ ]*\).*/\1/p'`

# let's setup all the flow rules
$CMD_PATH/ovsv1.sh $CMD $NAME $POD_IP $POD_PORT $VNID $HOST_SUBNET $POD_MAC

