#!/bin/bash
set -ex

CMD=$1
OVS_BRIDGE=$2
PORT_NAME=$3
POD_IP=$4
POD_PORT=$5
VNID=$6
# POD_MAC=$7

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


add_port(){

	ovs-vsctl add-port $OVS_BRIDGE $PORT_NAME -- set Interface $PORT_NAME ofport_request=$POD_PORT

	########################
	# Table 13: Ingress from Cluster Gateway
	########################
	# 	Rules should be added if pod has egress access
	# ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	# 	"table=${TABLE_INGRESS_CGW},priority=100,ip,nw_dst=${POD_IP},actions=output:${POD_PORT}"
	# # ARP
	# ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	# 	"table=${TABLE_INGRESS_CGW},priority=100,arp,nw_dst=${POD_IP},actions=output:${POD_PORT}"
	# NOTE: the host and any container running locally (outside ovs control e.g. docker container on host) can
	# reach the containers on the same host. we can change this if desired later.

	########################
	# 15. VNI Tag in REG0 (Table 15)
	########################
	ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
		"table=${TABLE_INGRESS_HOST_POD},priority=100,in_port=${POD_PORT},ip,nw_src=${POD_IP},actions=load:${VNID}->NXM_NX_REG0[],goto_table:${TABLE_ACL}"
	# ARP
	ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
		"table=${TABLE_INGRESS_HOST_POD},priority=100,in_port=${POD_PORT},arp,nw_src=${POD_IP},actions=load:${VNID}->NXM_NX_REG0[],goto_table:${TABLE_ACL}"

	########################
	# Table 17: ACL
	########################
	# Service Rules. Ex: TCP, REG0=0x1234,nw_dst=172.45.2.5,rp=8080 actions=output:2
	# TBD
	# Enable external access:
	# We could put more granular control here. E.G. tcp on port 80...
	# ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	# 	"table=${TABLE_ACL},priority=50,in_port=${POD_PORT},ip,nw_src=${POD_IP},actions=goto_table:${TABLE_ROUTER}"

	########################
	# Table: TABLE_ARP_RESPONDER
	########################
	# FLOATING_IP="10.1.1.235"
	# tmp=`echo ${FLOATING_IP//./ }`
	# FLOATING_IP_HEX=`printf '%02X' $tmp`
	# POD_MAC_HEX=`echo $POD_MAC | sed -e 's/://g'`
	# ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	# 	"table=${TABLE_ARP_RESPONDER},priority=100,arp,nw_dst=${FLOATING_IP},actions=move:NXM_OF_ETH_SRC[]->NXM_OF_ETH_DST[],\
	# 	mod_dl_src:${POD_MAC},\
	# 	load:0x2->NXM_OF_ARP_OP[],\
	# 	move:NXM_NX_ARP_SHA[]->NXM_NX_ARP_THA[],\
	# 	move:NXM_OF_ARP_SPA[]->NXM_OF_ARP_TPA[],\
	# 	load:0x${POD_MAC_HEX}->NXM_NX_ARP_SHA[],\
	# 	load:0x${FLOATING_IP_HEX}->NXM_OF_ARP_SPA[],\
	# 	move:NXM_OF_IN_PORT[]->NXM_NX_REG3[0..15],\
	# 	load:0->NXM_OF_IN_PORT[],\
	# 	output:NXM_NX_REG3[0..15]"

	########################
	# Table 50: Egress to Local Pods
	########################
	# 	i. Allow traffic to same VNI
	# ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
		# "table=${TABLE_EGRESS_LOCAL_POD},priority=100,ip,reg0=${VNID},nw_dst=${POD_IP},actions=output:${POD_PORT}"
	# ARP
	# ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	# 	"table=${TABLE_EGRESS_LOCAL_POD},priority=100,arp,reg0=${VNID},nw_dst=${POD_IP},actions=output:${POD_PORT}"

	# 	NOTE: dropping VNID CHECK for the time being. ............................
	# ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	# 	"table=${TABLE_EGRESS_LOCAL_POD},priority=100,ip,nw_dst=${POD_IP},actions=output:${POD_PORT}"
	# # ARP
	ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
		"table=${TABLE_EGRESS_LOCAL_POD},priority=100,arp,nw_dst=${POD_IP},actions=output:${POD_PORT}"


	# Allow traffic to other VNIs if policy allows
	# TBD

}

del_port(){

	ovs-vsctl del-port $OVS_BRIDGE $PORT_NAME

	########################
	# Table 13: Ingress from Cluster Gateway
	########################
	# 	Rules should be added if pod has egress access
	# ovs-ofctl -O OpenFlow13 del-flows $OVS_BRIDGE "table=${TABLE_INGRESS_CGW},ip,nw_dst=${POD_IP}"
	# # ARP
	# ovs-ofctl -O OpenFlow13 del-flows $OVS_BRIDGE "table=${TABLE_INGRESS_CGW},arp,nw_dst=${POD_IP}"

	########################
	# 15. VNI Tag in REG0 (Table 15)
	########################
	#  could also delete based on port: in_port=${POD_PORT}
	ovs-ofctl -O OpenFlow13 del-flows $OVS_BRIDGE "table=${TABLE_INGRESS_HOST_POD},ip,nw_src=${POD_IP}"
	# ARP
	ovs-ofctl -O OpenFlow13 del-flows $OVS_BRIDGE "table=${TABLE_INGRESS_HOST_POD},arp,nw_src=${POD_IP}"

	########################
	# Table 17: ACL
	########################
	# ovs-ofctl -O OpenFlow13 del-flows $OVS_BRIDGE "table=${TABLE_ACL},in_port=${POD_PORT},ip,nw_src=${POD_IP}"

	########################
	# Table 50: Egress to Local Pods
	########################
	# 	i. Allow traffic to same VNI
	# ovs-ofctl -O OpenFlow13 del-flows $OVS_BRIDGE "table=${TABLE_EGRESS_LOCAL_POD},ip,nw_dst=${POD_IP}"
	# # ARP
	ovs-ofctl -O OpenFlow13 del-flows $OVS_BRIDGE "table=${TABLE_EGRESS_LOCAL_POD},arp,nw_dst=${POD_IP}"

	# Allow traffic to other VNIs if policy allows
	# TBD
}

case "$CMD" in
	add)
		add_port
		;;
	del)
		del_port
		;;
	*)
		echo "Invalid cmd: $@"
		exit 1
	esac
