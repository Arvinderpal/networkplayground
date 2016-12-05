#!/bin/bash
set -ex

# /vagrant/netscripts/vxlan/simplenetwork.sh 10.1.1. 10.1.1.0/24 192.168.70.201

# the script is generally called by Vagrantfile to setup default networks
OVS_BRIDGE=ovs-br

CMD_PATH="/vagrant/netscripts/vxlan/"
HOST_NAME=$1
IP_PREFIX=$2 # e.g. 10.1.2.
HOST_SUBNET=$3 # e.g. 10.1.1.0/24
BOX_IP=$4 # e.g. 192.168.70.201

#  for a unique port number, we remove the '.' from the ip address

VNID1="100"
$CMD_PATH/addnetns.sh ns1 $IP_PREFIX"2" ${IP_PREFIX//.}"2" $VNID1 $HOST_SUBNET $BOX_IP

VNID2="200"
$CMD_PATH/addnetns.sh ns2 $IP_PREFIX"3" ${IP_PREFIX//.}"3" $VNID2 $HOST_SUBNET $BOX_IP


# add rules 

# TCP:
# allow ns1 on host etcd-01 to receive (ingress) traffic from ns1 on host etcd-02. 
MY_IP="10.1.1.2"
PEER_IP="10.1.2.2"
PROTO="tcp"
PROTO_PORT="12000"
POLICY_UID="0123456789ABCDEF"
if [[ $HOST_NAME =~ "etcd-01" ]] ; then 
	$CMD_PATH/allow_ingress.sh "to_me" $POLICY_UID $MY_IP $PEER_IP $PROTO $PROTO_PORT ${MY_IP//.} > /tmp/allow-ingress-$HOST_NAME.txt
	cat /tmp/allow-ingress-$HOST_NAME.txt
	# ovs-ofctl -O OpenFlow14 --bundle replace-flows $OVS_BRIDGE /tmp/allow-ingress-$HOST_NAME.txt
	ovs-ofctl -O OpenFlow14 --bundle add-flows $OVS_BRIDGE /tmp/allow-ingress-$HOST_NAME.txt
fi
# note MY_IP and PEER_IP are switched:
if [[ $HOST_NAME =~ "etcd-02" ]] ; then 
	$CMD_PATH/allow_ingress.sh  "from_peer" $POLICY_UID $PEER_IP $MY_IP $PROTO $PROTO_PORT ${PEER_IP//.} > /tmp/allow-ingress-$HOST_NAME.txt
	cat /tmp/allow-ingress-$HOST_NAME.txt
	ovs-ofctl -O OpenFlow14 --bundle add-flows $OVS_BRIDGE /tmp/allow-ingress-$HOST_NAME.txt
	# ovs-ofctl -O OpenFlow14 --bundle replace-flows $OVS_BRIDGE /tmp/allow-ingress-$HOST_NAME.txt
fi

# UDP
# allow ns1 on host etcd-01 to receive (ingress) traffic from ns1 on host etcd-02. 
MY_IP="10.1.1.2"
PEER_IP="10.1.2.2"
PROTO="udp"
PROTO_PORT="11000"
POLICY_UID="2222222222222222"
if [[ $HOST_NAME =~ "etcd-01" ]] ; then 
	$CMD_PATH/allow_ingress.sh "to_me" $POLICY_UID $MY_IP $PEER_IP $PROTO $PROTO_PORT ${MY_IP//.} > /tmp/allow-ingress-$HOST_NAME.txt
	cat /tmp/allow-ingress-$HOST_NAME.txt
	# ovs-ofctl -O OpenFlow14 --bundle replace-flows $OVS_BRIDGE /tmp/allow-ingress-$HOST_NAME.txt
	ovs-ofctl -O OpenFlow14 --bundle add-flows $OVS_BRIDGE /tmp/allow-ingress-$HOST_NAME.txt
fi
# note MY_IP and PEER_IP are switched:
if [[ $HOST_NAME =~ "etcd-02" ]] ; then 
	$CMD_PATH/allow_ingress.sh  "from_peer" $POLICY_UID $PEER_IP $MY_IP $PROTO $PROTO_PORT ${PEER_IP//.} > /tmp/allow-ingress-$HOST_NAME.txt
	cat /tmp/allow-ingress-$HOST_NAME.txt
	ovs-ofctl -O OpenFlow14 --bundle add-flows $OVS_BRIDGE /tmp/allow-ingress-$HOST_NAME.txt
	# ovs-ofctl -O OpenFlow14 --bundle replace-flows $OVS_BRIDGE /tmp/allow-ingress-$HOST_NAME.txt
fi

# allow ns1 on host etcd-01 to receive (ingress) traffic from ns2 on same host
MY_IP="10.1.1.2"
PEER_IP="10.1.1.3"
PROTO="tcp"
PROTO_PORT="11000"
POLICY_UID="1111111111111111"
if [[ $HOST_NAME =~ "etcd-01" ]] ; then 
	# we delete all rules belonging to the policy on this host, then insert new ones. all as part of single transaction
	echo delete "cookie=0x${POLICY_UID}/-1" > /tmp/allow-ingress-same-host-$HOST_NAME.txt
	$CMD_PATH/allow_ingress_same_host.sh "to_me" $POLICY_UID $MY_IP $PEER_IP $PROTO $PROTO_PORT ${MY_IP//.} >> /tmp/allow-ingress-same-host-$HOST_NAME.txt
	$CMD_PATH/allow_ingress_same_host.sh  "from_peer" $POLICY_UID $PEER_IP $MY_IP $PROTO $PROTO_PORT ${PEER_IP//.} >> /tmp/allow-ingress-same-host-$HOST_NAME.txt
	cat /tmp/allow-ingress-same-host-$HOST_NAME.txt
	ovs-ofctl -O OpenFlow14 --bundle add-flows $OVS_BRIDGE /tmp/allow-ingress-same-host-$HOST_NAME.txt
fi


# allow ns2 on etcd-1 and ns1/ns2 etcd-02 to be on the "open" network
POLICY_UID="F000000000000000"
if [[ $HOST_NAME =~ "etcd-01" ]] ; then 
	MY_IP="10.1.1.3"
	# $CMD_PATH/isolation_on_off.sh "on" $POLICY_UID $MY_IP ${MY_IP//.} "0" >> /tmp/isolation-off-$HOST_NAME.txt
	$CMD_PATH/isolation_on_off.sh "off" $POLICY_UID $MY_IP ${MY_IP//.} "0" > /tmp/isolation-off-$HOST_NAME.txt
	cat /tmp/isolation-off-$HOST_NAME.txt
	ovs-ofctl -O OpenFlow14 --bundle add-flows $OVS_BRIDGE /tmp/isolation-off-$HOST_NAME.txt
fi
if [[ $HOST_NAME =~ "etcd-02" ]] ; then 
	MY_IP="10.1.2.2"
	$CMD_PATH/isolation_on_off.sh "off" $POLICY_UID $MY_IP ${MY_IP//.} "0" > /tmp/isolation-off-$HOST_NAME.txt

	MY_IP="10.1.2.3"
	$CMD_PATH/isolation_on_off.sh "off" $POLICY_UID $MY_IP ${MY_IP//.} "0" >> /tmp/isolation-off-$HOST_NAME.txt

	cat /tmp/isolation-off-$HOST_NAME.txt
	ovs-ofctl -O OpenFlow14 --bundle add-flows $OVS_BRIDGE /tmp/isolation-off-$HOST_NAME.txt
fi


# # allow ns2 on etcd-2 and ns1 and ns2 etcd-03 to be on the "open" network
# POLICY_UID="F000000000000000"
# if [[ $HOST_NAME =~ "etcd-02" ]] ; then 
# 	MY_IP="10.1.2.3"
# 	# $CMD_PATH/isolation_on_off.sh "on" $POLICY_UID $MY_IP ${MY_IP//.} "0" >> /tmp/isolation-off-$HOST_NAME.txt
# 	$CMD_PATH/isolation_on_off.sh "off" $POLICY_UID $MY_IP ${MY_IP//.} "0" > /tmp/isolation-off-$HOST_NAME.txt
# 	cat /tmp/isolation-off-$HOST_NAME.txt
# 	ovs-ofctl -O OpenFlow14 --bundle add-flows $OVS_BRIDGE /tmp/isolation-off-$HOST_NAME.txt
# fi
# if [[ $HOST_NAME =~ "etcd-03" ]] ; then 
# 	MY_IP="10.1.3.2"
# 	$CMD_PATH/isolation_on_off.sh "off" $POLICY_UID $MY_IP ${MY_IP//.} "0" > /tmp/isolation-off-$HOST_NAME.txt

# 	MY_IP="10.1.3.3"
# 	$CMD_PATH/isolation_on_off.sh "off" $POLICY_UID $MY_IP ${MY_IP//.} "0" >> /tmp/isolation-off-$HOST_NAME.txt

# 	cat /tmp/isolation-off-$HOST_NAME.txt
# 	ovs-ofctl -O OpenFlow14 --bundle add-flows $OVS_BRIDGE /tmp/isolation-off-$HOST_NAME.txt
# fi
