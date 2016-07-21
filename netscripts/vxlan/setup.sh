#!/bin/bash
set -ex

# /vagrant/netscripts/vxlan/setup.sh 10.1.0.0/16 10.1.1.0/24 10.1.2.0/24 10.1.3.0/24 192.168.70.202 192.168.70.203 eth1

OVS_BRIDGE=ovs-br
TUN_TYPE='vxlan'
TUN_PORT="1"

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

# EXTERNAL_IF="eth0"
EXTERNAL_IF=$7
EXTERNAL_PORT="2"

EXTERNAL_IF_MAC=`ip link show dev $EXTERNAL_IF | sed -n -e 's/.*link.ether \([^ ]*\).*/\1/p'`
EXTERNAL_IF_MAC_HEX=`echo $EXTERNAL_IF_MAC | sed -e 's/://g'`

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
TABLE_ARP_RESPONDER="5"
TABLE_INGRESS_TUN="10"
TABLE_INGRESS_EXTERNAL_PORT="12"
TABLE_INGRESS_CSG="13"
TABLE_INGRESS_LOCAL_PORT="14"
TABLE_INGRESS_HOST_POD="15"
TABLE_ACL="17"
TABLE_NAT="20"
TABLE_ROUTER="40"
TABLE_DE_NAT_EXTERNAL_IN_PHASE_1="42"
TABLE_DE_NAT_EXTERNAL_IN_PHASE_2="43"
TABLE_ARP_EXTERNAL="45"
TABLE_NAT_EXTERNAL_PHASE_1="47"
TABLE_NAT_EXTERNAL_PHASE_2="49"
TABLE_EGRESS_LOCAL_POD="50"
TABLE_EGRESS_TUN="55"
TABLE_EGRESS_EXTERNAL_PORT="58"
TABLE_EGRESS_LOCAL_PORT="60"


########################
# Table 0: Classify
########################
# 	a. From tunnel (Table 10)
# 	b. From external interface (Table 20)
#   d. From Cluster GW 
# 	c. From local pods (Table 15)
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_CLASSIFY},priority=100,in_port=${TUN_PORT},actions=goto_table:${TABLE_INGRESS_TUN}"
# ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
# 	"table=${TABLE_CLASSIFY},priority=100,in_port=LOCAL,actions=goto_table:${TABLE_NAT}"

ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_CLASSIFY},priority=100,ip,in_port=${CLUSTERSUBNETGW_PORT},actions=goto_table:${TABLE_ACL}"
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_CLASSIFY},priority=100,arp,in_port=${CLUSTERSUBNETGW_PORT},actions=goto_table:${TABLE_ARP_RESPONDER}"

# Traffic from local linux stack
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_CLASSIFY},in_port=LOCAL,actions=goto_table:${TABLE_INGRESS_LOCAL_PORT}"
# Traffic from eth1 
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_CLASSIFY},in_port=${EXTERNAL_PORT},actions=goto_table:${TABLE_INGRESS_EXTERNAL_PORT}"

ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_CLASSIFY},priority=1,actions=goto_table:${TABLE_INGRESS_HOST_POD}"

########################
# Table 5: TABLE_ARP_RESPONDER
########################
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_ARP_RESPONDER},priority=1,arp,actions=goto_table:${TABLE_ROUTER}"

########################
# Table 12: Ingress from ovs External Port
########################
# FLOATING_IP="172.16.60.235"
# FLOATING_IP="10.1.1.235"
FLOATING_IP=$BOX_IP #"192.168.70.201"
TPORT="34567-40000"
# Track all traffic from external port, reverse nat tracked connections
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_INGRESS_EXTERNAL_PORT},priority=100,icmp,actions=goto_table:${TABLE_DE_NAT_EXTERNAL_IN_PHASE_1}"
# "table=${TABLE_INGRESS_EXTERNAL_PORT},priority=100,icmp,actions=ct(zone=1,nat),LOCAL"

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
# icmp:
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_INGRESS_LOCAL_PORT},priority=100,icmp,nw_src=${CLUSTER_SUBNET},actions=ct(commit,zone=1,nat(src=${FLOATING_IP}),exec(set_field:1->ct_mark)),${EXTERNAL_PORT}"
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
# 	a. Allow traffic in cluster subnet (Table 40)
# 	b. Allow traffic to service
# 		i. Send out external interface
# 	c. If policy set, allow traffic to external networks, else drop
# 		i. Rewrite (Table 20)
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_ACL},priority=100,ip,nw_dst=${CLUSTER_SUBNET},actions=goto_table:${TABLE_ROUTER}"
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_ACL},priority=100,arp,nw_dst=${CLUSTER_SUBNET},actions=goto_table:${TABLE_ROUTER}"

# Service Rules. Ex: TCP, REG0=0x1234,nw_dst=172.45.2.5,rp=8080 actions=output:2
# TBD

# ARP to gateway signifies that pod trying to talk to external worl:
# NOTE: priority should be > above rules for arp to gw
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_ACL},priority=200,arp,nw_dst=${CLUSTER_SUBNET_GW},actions=goto_table:${TABLE_ROUTER}"
# Track all IP traffic, NAT existing connections.

# FLOATING_IP="172.16.60.235"
# FLOATING_IP="10.1.1.235"
# TPORT="34567"
# ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
# 	"table=${TABLE_ACL},priority=200,icmp,in_port=${CLUSTERSUBNETGW_PORT},nw_dst=10.1.1.235,actions=ct(table=${TABLE_CLASSIFY},zone=1,nat)"
# ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
# 	"table=${TABLE_ACL},priority=200,icmp,in_port=${CLUSTERSUBNETGW_PORT},ct_state=+trk+rel,ct_mark=1,ct_zone=1,actions=goto_table:${TABLE_ROUTER}"
# ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
# 	"table=${TABLE_ACL},priority=50,actions=goto_table:${TABLE_NAT}"

ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_ACL},priority=50,actions=goto_table:${TABLE_ROUTER}"


# Drop all external traffic:
# ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
# 	"table=${TABLE_ACL},priority=1,actions=drop"
# To enable, we can enable based on VNID, which should already be loaded into reg0
# ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
# 	"table=${TABLE_ACL},priority=50,ip,reg0=<<VNID>>,actions=${TABLE_NAT}"

########################
# Table 20. NAT From Pods
########################
# 	a. SNAT traffic from pods and send towards external interface
# 	b. Only allow traffic to extablished connections from external interface

# Allow any traffic from pod->external world. SNAT pod to the host's IP
# in_port=1,tcp,action=ct(commit,zone=1,nat(src=10.1.1.240-10.1.1.255:34567-34568,random)),2
# ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
# 	"table=${TABLE_NAT},priority=100,ip,actions=ct(commit,zone=1,nat(src=${FLOATING_IP})),goto_table:${TABLE_ROUTER}"
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_NAT},priority=100,icmp,actions=ct(commit,zone=1,nat(src=${FLOATING_IP}),exec(set_field:1->ct_mark)),goto_table:${TABLE_ROUTER}"

# ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
# 	"table=${TABLE_NAT},priority=100,ip,ct_state=+trk-new+est,actions=goto_table:${TABLE_ROUTER}"

# For traffic from external world, if part of tracked and established traffic, send to router
# in_port=2,ct_state=-trk,tcp,tp_dst=34567,action=ct(table=0,zone=1,nat)
# ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
# 	"table=${TABLE_NAT},priority=100,ip,in_port=${CLUSTERSUBNETGW_PORT},ct_state=+trk,ct_zone=1,actions=goto_table:${TABLE_ROUTER}"


# For traffic from external world, if not tracked, then send out LOCAL and let linux stack handle it
# ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
# 	"table=${TABLE_NAT},priority=0,action=LOCAL"

ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_NAT},priority=0,action=goto_table:${TABLE_ROUTER}"


########################
# Table 25. NAT From External World
########################

########################
# 40. Router (Table 40)
########################
# To gateway [external]
# 	Ø nw_dst=192.168.1.1[GW] actions=output=2
# TBD

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
# To cluster gateway:
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_ROUTER},priority=200,ip,nw_dst=${CLUSTER_SUBNET_GW},actions=output:${CLUSTERSUBNETGW_PORT}"
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_ROUTER},priority=200,arp,nw_dst=${CLUSTER_SUBNET_GW},actions=goto_table:${TABLE_ARP_EXTERNAL}"
# External Traffic to Local Pod
# in_port=2,ct_state=-trk,tcp,tp_dst=34567,action=ct(table=0,zone=1,nat)
# ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
# 	"table=${TABLE_ROUTER},priority=200,ip,in_port=${CLUSTERSUBNETGW_PORT},nw_dst=${HOST_SUBNET},actions=goto_table:${TABLE_INGRESS_CSG}"

# external traffic from pods being sent directly to external interface
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_ROUTER},priority=1,dl_dst=${EXTERNAL_IF_MAC},actions=goto_table:${TABLE_NAT_EXTERNAL_PHASE_1}"

# All other traffic:
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_ROUTER},priority=1,actions=output:${CLUSTERSUBNETGW_PORT}"


########################
# Table: TABLE_ARP_EXTERNAL
########################
# FLOATING_IP="10.1.1.235"
tmp=`echo ${CLUSTER_SUBNET_GW//./ }`
CLUSTER_SUBNET_GW_IP_HEX=`printf '%02X' $tmp`

ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_ARP_EXTERNAL},priority=100,arp,actions=\
	move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[],\
	mod_dl_src:${EXTERNAL_IF_MAC},\
	load:0x2->NXM_OF_ARP_OP[],\
	move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[],\
	move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[],\
	load:0x${EXTERNAL_IF_MAC_HEX}->NXM_NX_ARP_SHA[],\
	load:0x${CLUSTER_SUBNET_GW_IP_HEX}->NXM_OF_ARP_SPA[],\
	move:NXM_OF_IN_PORT[]->NXM_NX_REG3[0..15],\
	load:0->NXM_OF_IN_PORT[],\
	output:NXM_NX_REG3[0..15]"


########################
# Table: TABLE_NAT_EXTERNAL_PHASE_1
########################

# icmp:
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_NAT_EXTERNAL_PHASE_1},priority=100,icmp,actions=ct(commit,zone=1,nat(src=${BOX_IP})),goto_table=${TABLE_NAT_EXTERNAL_PHASE_2}"

########################
# Table: TABLE_NAT_EXTERNAL_PHASE_2
########################

# DEFAULT_GW_IP=`/sbin/ip route | awk '/default/ { print $3 }'`
DEFAULT_GW_IP=172.16.60.2
# DEFAULT_GW_MAC=`arp | grep "${DEFAULT_GW_IP} " | awk '{print $3}'`
DEFAULT_GW_MAC=00:50:56:eb:ff:a1

ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_NAT_EXTERNAL_PHASE_2},actions=mod_dl_src=${EXTERNAL_IF_MAC},mod_dl_dst=${DEFAULT_GW_MAC},${EXTERNAL_PORT}"




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

########################
# Table 58: Egress to External World
########################
# TBD

