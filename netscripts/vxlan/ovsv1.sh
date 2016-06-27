#!/bin/bash
set -ex

CMD=$1
NETNS=$2
POD_IP=$3
POD_PORT=$4
VNID=$5
HOSTSUBNET=$6 # e.g. 10.1.5.0/24
# REMOTETUN_IP=$6

OVS_BRIDGE=ovs-br
TUN_TYPE='vxlan'
VXLAN_PORT="1"
EXTERNAL_PORT="2"

TABLE_INGRESS_TUN="10"
TABLE_INGRESS_LOCAL="15"
TABLE_ACL="17"
TABLE_EGRESS_LOCAL="50"
TABLE_EGRESS_TUN="55"
TABLE_EGRESS_EXT="58"

add_flows(){
	########################
	# Table 10: Ingress from Tunnel
	########################
	ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
		"table=${TABLE_INGRESS_TUN},priority=100,ip,nw_dst=${HOSTSUBNET},actions=move:NXM_NX_TUN_ID[0..31]->NXM_NX_REG0[],goto_table:${TABLE_ACL}"
	# ARP
	ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
		"table=${TABLE_INGRESS_TUN},priority=100,arp,nw_dst=${HOSTSUBNET},actions=move:NXM_NX_TUN_ID[0..31]->NXM_NX_REG0[],goto_table:${TABLE_ACL}"
	########################
	# 15. VNI Tag in REG0 (Table 15)
	########################
	ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE "table=${TABLE_INGRESS_LOCAL},priority=100,in_port=${POD_PORT},ip,nw_src=${POD_IP},actions=load:${VNID}->NXM_NX_REG0[],goto_table:${TABLE_ACL}"
	# ARP
	ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE "table=${TABLE_INGRESS_LOCAL},priority=100,in_port=${POD_PORT},arp,nw_src=${POD_IP},actions=load:${VNID}->NXM_NX_REG0[],goto_table:${TABLE_ACL}"

	########################
	# Table 50: Egress to Local Pods
	########################
	# 	i. Allow traffic to same VNI
	ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
		"table=${TABLE_EGRESS_LOCAL},priority=100,ip,reg0=${VNID},nw_dst=${POD_IP},actions=output:${POD_PORT}"
	# ARP
	ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
		"table=${TABLE_EGRESS_LOCAL},priority=100,arp,reg0=${VNID},nw_dst=${POD_IP},actions=output:${POD_PORT}"

	# Allow traffic to other VNIs if policy allows
	# TBD
}

case "$CMD" in
	add)
		add_flows
		;;
	*)
		echo "Invalid cmd: $@"
		exit 1
	esac
