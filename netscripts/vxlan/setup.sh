#!/bin/bash
set -ex

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

OVS_BRIDGE=ovs-br
TUN_TYPE='vxlan'
TUN_PORT="1"
EXTERNAL_PORT="2"

# create the switch
ovs-vsctl --may-exist add-br $OVS_BRIDGE -- set Bridge $OVS_BRIDGE fail-mode=secure

# Create tunnel 
ovs-vsctl add-port $OVS_BRIDGE vxlan0 -- set interface vxlan0 \
	ofport_request=$TUN_PORT \
	type=vxlan \
	options:remote_ip=flow options:key=flow

# TABLES
TABLE_CLASSIFY="0"
TABLE_INGRESS_TUN="10"
TABLE_INGRESS_LOCAL="15"
TABLE_ACL="17"
TABLE_NAT="20"
TABLE_ROUTER="40"
TABLE_EGRESS_LOCAL="50"
TABLE_EGRESS_TUN="55"
TABLE_EGRESS_EXT="58"

########################
# Table 0: Classify
########################
# 	a. From tunnel (Table 10)
# 	b. From external interface (Table 20)
# 	c. From local pods (Table 15)
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_CLASSIFY},in_port=${TUN_PORT},actions=goto_table:${TABLE_INGRESS_TUN}"
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_CLASSIFY},in_port=${EXTERNAL_PORT},actions=goto_table:${TABLE_NAT}"
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_CLASSIFY},priority=1,actions=goto_table:${TABLE_INGRESS_LOCAL}"

########################
# Table 10: Ingress from Tunnel
# flows added during pod add/del
########################

########################
# Table 15: VNI Tag in REG0 
# flows added during pod add/del
########################

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

# By default all external traffic is dropped. it can be enabled per namespace through policy
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_ACL},priority=1,actions=drop"
# To enable, we can enable based on VNID, which should already be loaded into reg0
# ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
# 	"table=${TABLE_ACL},priority=50,ip,reg0=<<VNID>>,actions=${TABLE_NAT}"

########################
# 20. NAT (Table 20)
########################
# 	a. Send out external interface
# TBD

########################
# 40. Router (Table 40)
########################
# To gateway [external]
# 	Ø nw_dst=192.168.1.1[GW] actions=output=2
# TBD

# To local pod:
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_ROUTER},priority=100,ip,nw_dst=${HOST_SUBNET},actions=goto_table:${TABLE_EGRESS_LOCAL}"
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_ROUTER},priority=100,arp,nw_dst=${HOST_SUBNET},actions=goto_table:${TABLE_EGRESS_LOCAL}"
# To remote pod [another cluster node]:
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_ROUTER},priority=50,ip,nw_dst=${CLUSTER_SUBNET},actions=goto_table:${TABLE_EGRESS_TUN}"
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_ROUTER},priority=50,arp,nw_dst=${CLUSTER_SUBNET},actions=goto_table:${TABLE_EGRESS_TUN}"
# All other traffic:
ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	"table=${TABLE_ROUTER},priority=1,actions=output:${EXTERNAL_PORT}"

########################
# Table 50: Egress to Pods
# flows added during pod add/del
########################

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