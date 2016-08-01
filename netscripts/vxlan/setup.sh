#!/bin/bash
set -ex

# /vagrant/netscripts/vxlan/setup.sh 10.1.0.0/16 10.1.1.0/24 10.1.2.0/24 10.1.3.0/24 192.168.70.202 192.168.70.203 192.168.70.201

OVS_BRIDGE=ovs-br
TUN_TYPE='vxlan'
TUN_PORT="1"

EXTERNAL_IF="eth0"
EXTERNAL_PORT="2"

CLUSTERSUBNETGW_IF="csg0"
CLUSTERSUBNETGW_PORT="3"

# cluster wide subnet 
CLUSTER_SUBNET=$1 #="10.1.0.0/16"

# subnet allocated to this host
HOST_SUBNET=$2 # e.g. 10.1.5.0/24

# subnets allocated to remote nodes
REMOTE1_SUBNET=$3
REMOTE2_SUBNET=$4
# Physical IPs of remote nodes
REMOTE1_IP=$5 
REMOTE2_IP=$6

# BOX_IP=$7
BOX_IP=''
ETH_IP=`ifconfig $EXTERNAL_IF | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p'`
BR_IP=`ifconfig $OVS_BRIDGE | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p'`
if [ -z "$ETH_IP" ]
then
	BOX_IP=$BR_IP
else
  	BOX_IP=$ETH_IP
fi     

echo "BOX IP: ${BOX_IP}"

# FLOATING_IP="172.16.60.235"
# FLOATING_IP="10.1.1.235"
FLOATING_IP=$BOX_IP #"192.168.70.201"
TPORT="34567-40000"

# clean up old state:
/vagrant/netscripts/vxlan/cleanall.sh

# create the switch
ovs-vsctl --may-exist add-br $OVS_BRIDGE -- set Bridge $OVS_BRIDGE fail-mode=secure

# Create external interface
ovs-vsctl --may-exist add-port $OVS_BRIDGE $EXTERNAL_IF -- set interface $EXTERNAL_IF ofport_request=$EXTERNAL_PORT
ifconfig $EXTERNAL_IF 0
ifconfig $OVS_BRIDGE "${BOX_IP}/24" up

# Create tunnel 
ovs-vsctl --may-exist add-port $OVS_BRIDGE vxlan0 -- set interface vxlan0 \
	ofport_request=$TUN_PORT \
	type=vxlan \
	options:remote_ip=flow options:key=flow

# Create default gateway to CLUSTERSUBNET
ovs-vsctl --may-exist add-port $OVS_BRIDGE $CLUSTERSUBNETGW_IF -- set interface $CLUSTERSUBNETGW_IF \
	type=internal \
	ofport_request=$CLUSTERSUBNETGW_PORT
CLUSTER_SUBNET_GW=`echo  $HOST_SUBNET | awk -F '.' '{ print $1 "." $2 "." $3 "." 1 }'`
ifconfig $CLUSTERSUBNETGW_IF "${CLUSTER_SUBNET_GW}/24" up

# for eth0 we also add default route to egress gateway
if [ "$EXTERNAL_IF" == "eth0" ]
then
	ip route add default via 172.16.60.2
fi

# Enable IP Forwarding
cat /proc/sys/net/ipv4/ip_forward
sudo echo 1 > /proc/sys/net/ipv4/ip_forward
cat /proc/sys/net/ipv4/ip_forward

# TABLES
TABLE_CLASSIFY="0"
# TABLE_ARP_RESPONDER="5"
TABLE_INGRESS_TUN="10"
TABLE_INGRESS_EXTERNAL_PORT="12"
TABLE_INGRESS_CGW="13"
TABLE_INGRESS_LOCAL_PORT="14"
TABLE_INGRESS_HOST_POD="15"
TABLE_ACL="17"
TABLE_ROUTER="40"
TABLE_EGRESS_LOCAL_POD="50"
TABLE_EGRESS_TUN="55"
TABLE_EGRESS_EXTERNAL_PORT="58"
TABLE_EGRESS_LOCAL_PORT="60"


########################
# Table 0: Classify
########################
# 	From tunnel 
# 	From external interface 
#   From Cluster GW 
#  	From LOCAL port
# 	From local pods (Table 15)
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_CLASSIFY},priority=100,in_port=${TUN_PORT},ip,actions=ct(table=${TABLE_INGRESS_TUN})"
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_CLASSIFY},priority=100,in_port=${TUN_PORT},arp,actions=goto_table:${TABLE_INGRESS_TUN}"
# Traffic from eth0/1 
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_CLASSIFY},priority=100,in_port=${EXTERNAL_PORT},actions=goto_table:${TABLE_INGRESS_EXTERNAL_PORT}"
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_CLASSIFY},priority=100,in_port=${CLUSTERSUBNETGW_PORT},actions=goto_table:${TABLE_INGRESS_CGW}"
# Traffic from local linux stack
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_CLASSIFY},priority=100,in_port=LOCAL,actions=goto_table:${TABLE_INGRESS_LOCAL_PORT}"

ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_CLASSIFY},priority=1,ip,actions=ct(table=${TABLE_INGRESS_HOST_POD})"
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_CLASSIFY},priority=1,arp,actions=goto_table:${TABLE_INGRESS_HOST_POD}"
########################
# Table 5: TABLE_ARP_RESPONDER
########################
# ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
# 	"table=${TABLE_ARP_RESPONDER},priority=1,arp,actions=goto_table:${TABLE_ROUTER}"

########################
# Table 10: Ingress from Tunnel
########################
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_INGRESS_TUN},priority=100,ip,nw_dst=${HOST_SUBNET},actions=move:NXM_NX_TUN_ID[0..31]->NXM_NX_REG0[],goto_table:${TABLE_ACL}"
# ARP
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_INGRESS_TUN},priority=100,arp,nw_dst=${HOST_SUBNET},actions=move:NXM_NX_TUN_ID[0..31]->NXM_NX_REG0[],goto_table:${TABLE_ACL}"


########################
# Table 12: Ingress from ovs External Port
########################
# Track all traffic from external port, reverse nat tracked connections
# udp:
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_INGRESS_EXTERNAL_PORT},priority=100,ct_state=-trk,udp,actions=ct(zone=1,nat),LOCAL"
# ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
# 	"table=${TABLE_INGRESS_EXTERNAL_PORT},priority=100,ct_state=+trk+rel,udp,actions=ct(zone=1,nat),LOCAL"

# icmp:
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_INGRESS_EXTERNAL_PORT},priority=100,icmp,actions=ct(zone=1,nat),LOCAL"
# tcp:
# allow NEW and ESTABLISHED packets to leave your local network, only allow ESTABLISHED connections back, 
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_INGRESS_EXTERNAL_PORT},priority=100,ct_state=-trk,tcp,actions=ct(zone=1,nat),LOCAL"
# ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
# 	"table=${TABLE_INGRESS_EXTERNAL_PORT},priority=100,ct_state=+trk,ct_zone=1,tcp,actions=LOCAL"
# ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
# 	"table=${TABLE_INGRESS_EXTERNAL_PORT},priority=100,icmp,ct_state=+trk+rel,ct_mark=1,ct_zone=1,actions=goto_table:${TABLE_ROUTER}"

# all other traffic goes to LOCAL
# TODO: we should be put tighter controls on traffic that we allow in since ip forwarding is enabled.
# For example, we should only allow traffic with dst of this host. also enable arps (and possibly stp) traffic
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_INGRESS_EXTERNAL_PORT},priority=1,actions=LOCAL"


########################
# Table 14: Ingress from ovs LOCAL Port
########################
# SNAT traffic from cluster pods and send to EXTERNAL port
# udp:
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_INGRESS_LOCAL_PORT},priority=100,udp,nw_src=${CLUSTER_SUBNET},actions=ct(commit,zone=1,nat(src=${FLOATING_IP})),${EXTERNAL_PORT}"
# icmp:
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_INGRESS_LOCAL_PORT},priority=100,icmp,nw_src=${CLUSTER_SUBNET},actions=ct(commit,zone=1,nat(src=${FLOATING_IP})),${EXTERNAL_PORT}"
# tcp: 
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_INGRESS_LOCAL_PORT},priority=100,ct_state=+new-est,tcp,nw_src=${CLUSTER_SUBNET},actions=ct(commit,zone=1,nat(src=${FLOATING_IP}:${TPORT})),${EXTERNAL_PORT}"
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_INGRESS_LOCAL_PORT},priority=100,ct_state=-new+est,tcp,nw_src=${CLUSTER_SUBNET},actions=ct(commit,zone=1,nat(src=${FLOATING_IP}:${TPORT})),${EXTERNAL_PORT}"
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_INGRESS_LOCAL_PORT},priority=100,ct_state=+est,tcp,nw_src=${FLOATING_IP},actions=output:${EXTERNAL_PORT}"

# all other traffic goes to external port 
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_INGRESS_LOCAL_PORT},priority=1,actions=${EXTERNAL_PORT}"

########################
# Table 17: ACL
########################
# 	Allow traffic in cluster subnet 
# 	Allow traffic to service
# 		> this should be added per pod in ovsv1.sh
# 	If policy set, allow traffic to external networks, else drop
# 		> this should be added per pod in ovsv1.sh

# ARP to gateway signifies that pod trying to talk to external worl:
# NOTE: priority should be > above rules for arp to gw
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_ACL},priority=200,arp,nw_dst=${CLUSTER_SUBNET_GW},actions=goto_table:${TABLE_ROUTER}"

# ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
# 	"table=${TABLE_ACL},priority=100,ip,nw_dst=${CLUSTER_SUBNET},actions=goto_table:${TABLE_ROUTER}"
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_ACL},priority=100,arp,nw_dst=${CLUSTER_SUBNET},actions=goto_table:${TABLE_ROUTER}"

# Drop all other traffic:
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_ACL},priority=1,actions=drop"


########################
# 40. Router (Table 40)
########################
# To cluster gateway:
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_ROUTER},priority=200,ip,nw_dst=${CLUSTER_SUBNET_GW},actions=output:${CLUSTERSUBNETGW_PORT}"
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_ROUTER},priority=200,arp,nw_dst=${CLUSTER_SUBNET_GW},actions=output:${CLUSTERSUBNETGW_PORT}"
# To local pod:
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_ROUTER},priority=100,ip,nw_dst=${HOST_SUBNET},actions=goto_table:${TABLE_EGRESS_LOCAL_POD}"
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_ROUTER},priority=100,arp,nw_dst=${HOST_SUBNET},actions=goto_table:${TABLE_EGRESS_LOCAL_POD}"
# To remote pod [another cluster node]:
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_ROUTER},priority=50,ip,nw_dst=${CLUSTER_SUBNET},actions=goto_table:${TABLE_EGRESS_TUN}"
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_ROUTER},priority=50,arp,nw_dst=${CLUSTER_SUBNET},actions=goto_table:${TABLE_EGRESS_TUN}"
# External Traffic to Local Pod
# in_port=2,ct_state=-trk,tcp,tp_dst=34567,action=ct(table=0,zone=1,nat)
# ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
# 	"table=${TABLE_ROUTER},priority=200,ip,in_port=${CLUSTERSUBNETGW_PORT},nw_dst=${HOST_SUBNET},actions=goto_table:${TABLE_INGRESS_CGW}"

# All other traffic:
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_ROUTER},priority=1,actions=output:${CLUSTERSUBNETGW_PORT}"

########################
# Table 50: Egress to Local Pods
########################
# Drop all other traffic:
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_EGRESS_LOCAL_POD},priority=1,actions=drop"


########################
# Table 55: Egress to Tunnel
########################
# These rules will be added during node add/del
# remote1
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_EGRESS_TUN},priority=100,ip,nw_dst=${REMOTE1_SUBNET},actions=move:NXM_NX_REG0[]->NXM_NX_TUN_ID[0..31],set_field:${REMOTE1_IP}->tun_dst,output:${TUN_PORT}"
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_EGRESS_TUN},priority=100,arp,nw_dst=${REMOTE1_SUBNET},actions=move:NXM_NX_REG0[]->NXM_NX_TUN_ID[0..31],set_field:${REMOTE1_IP}->tun_dst,output:${TUN_PORT}"
# remote2
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_EGRESS_TUN},priority=100,ip,nw_dst=${REMOTE2_SUBNET},actions=move:NXM_NX_REG0[]->NXM_NX_TUN_ID[0..31],set_field:${REMOTE2_IP}->tun_dst,output:${TUN_PORT}"
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_EGRESS_TUN},priority=100,arp,nw_dst=${REMOTE2_SUBNET},actions=move:NXM_NX_REG0[]->NXM_NX_TUN_ID[0..31],set_field:${REMOTE2_IP}->tun_dst,output:${TUN_PORT}"

