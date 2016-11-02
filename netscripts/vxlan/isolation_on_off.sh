#!/bin/bash
set -e

CMD=$1
COOKIE=$2
POD_IP=$3
POD_PORT=$4
VNID=$5
# POD_MAC=$7

OVS_BRIDGE=ovs-br

TUN_TYPE='vxlan'
VXLAN_PORT="1"
EXTERNAL_PORT="2"

# TABLES
TABLE_CLASSIFY="0"
# TABLE_ARP_RESPONDER="5"
TABLE_INGRESS_CGW="13"
TABLE_ACL="17"
TABLE_ROUTER="40"
TABLE_EGRESS_LOCAL_POD="50"


isolation_off(){

	########################
	# Table 13: Ingress from Cluster Gateway
	########################
	# 	Rules should be added if pod has egress access
	echo "table=${TABLE_INGRESS_CGW},cookie=0x${COOKIE},priority=100,ip,nw_dst=${POD_IP},actions=output:${POD_PORT}"
	# ARP
	echo "table=${TABLE_INGRESS_CGW},cookie=0x${COOKIE},priority=100,arp,nw_dst=${POD_IP},actions=output:${POD_PORT}"
	# NOTE: the host and any container running locally (outside ovs control e.g. docker container on host) can 
	# reach the containers on the same host. we can change this if desired later. 

	########################
	# Table 17: ACL
	########################
	# Service Rules. Ex: TCP, REG0=0x1234,nw_dst=172.45.2.5,rp=8080 actions=output:2
	# TBD

	# Enable external access: 
	# We could put more granular control here. E.G. tcp on port 80...
	echo "table=${TABLE_ACL},cookie=0x${COOKIE},priority=50,in_port=${POD_PORT},ip,nw_src=${POD_IP},actions=goto_table:${TABLE_ROUTER}"
	
	# Allow traffic from other pods and external inernet:
	echo "table=${TABLE_ACL},cookie=0x${COOKIE},priority=50,ip,nw_dst=${POD_IP},actions=goto_table:${TABLE_ROUTER}"

	########################
	# Table 50: Egress to Local Pods
	########################
	# 	i. Allow traffic to same VNID
	# ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	# 	"table=${TABLE_EGRESS_LOCAL_POD},priority=100,ip,reg0=${VNID},nw_dst=${POD_IP},actions=output:${POD_PORT}"
	# # ARP
	# ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	# 	"table=${TABLE_EGRESS_LOCAL_POD},priority=100,arp,reg0=${VNID},nw_dst=${POD_IP},actions=output:${POD_PORT}"

	# NO VNID check at all: We could use this approach if we can identify these rules based on a cookie -- say cookie=0xF000000000000000,
	echo "table=${TABLE_EGRESS_LOCAL_POD},cookie=0x${COOKIE},priority=100,ip,nw_dst=${POD_IP},actions=output:${POD_PORT}"
	# ARP
	echo "table=${TABLE_EGRESS_LOCAL_POD},cookie=0x${COOKIE},priority=100,arp,nw_dst=${POD_IP},actions=output:${POD_PORT}"

}


isolation_on(){
	# turning on isolation basically deletes the rules that were added while it was off
	# delete flows that match on both cookie AND POD_IP
	echo delete "cookie=0x${COOKIE}/-1,ip,nw_dst=${POD_IP}"	
	echo delete "cookie=0x${COOKIE}/-1,arp,nw_dst=${POD_IP}"	
	echo delete "cookie=0x${COOKIE}/-1,in_port=${POD_PORT},ip,nw_src=${POD_IP}"	
}

case "$CMD" in
	on)
		isolation_on
		;;
	off)
		isolation_off
		;;
	*)
		echo "Invalid cmd: $@"
		exit 1
	esac
