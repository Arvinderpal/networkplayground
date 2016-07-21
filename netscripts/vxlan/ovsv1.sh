#!/bin/bash
set -ex

CMD=$1
NETNS=$2
POD_IP=$3
POD_PORT=$4
VNID=$5
HOSTSUBNET=$6 # e.g. 10.1.5.0/24
POD_MAC=$7
# REMOTETUN_IP=$6

OVS_BRIDGE=ovs-br
TUN_TYPE='vxlan'
VXLAN_PORT="1"
EXTERNAL_PORT="2"

TABLE_CLASSIFY="0"
TABLE_ARP_RESPONDER="5"
TABLE_INGRESS_TUN="10"
TABLE_INGRESS_CSG="13"
TABLE_INGRESS_HOST_POD="15"
TABLE_ACL="17"
TABLE_DE_NAT_EXTERNAL_IN_PHASE_1="42"
TABLE_DE_NAT_EXTERNAL_IN_PHASE_2="43"
TABLE_EGRESS_LOCAL_POD="50"
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
	ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE "table=${TABLE_INGRESS_HOST_POD},priority=100,in_port=${POD_PORT},ip,nw_src=${POD_IP},actions=load:${VNID}->NXM_NX_REG0[],goto_table:${TABLE_ACL}"
	# ARP
	ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE "table=${TABLE_INGRESS_HOST_POD},priority=100,in_port=${POD_PORT},arp,nw_src=${POD_IP},actions=load:${VNID}->NXM_NX_REG0[],goto_table:${TABLE_ACL}"

	########################
	# Table 13: Ingress from Cluster Gateway
	########################
	# 	Rules should be added if pod has egress access
	ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
		"table=${TABLE_INGRESS_CSG},priority=100,ip,nw_dst=${POD_IP},actions=output:${POD_PORT}"
	# ARP
	ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
		"table=${TABLE_INGRESS_CSG},priority=100,arp,nw_dst=${POD_IP},actions=output:${POD_PORT}"
	# # 	From cluster GW but not for local pod, must be to an external IP
	# ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	# 	"table=${TABLE_INGRESS_CSG},priority=50,actions=output:LOCAL"
	# # ARP
	# ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	# 	"table=${TABLE_INGRESS_CSG},priority=50,arp,actions=output:LOCAL"


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
	# Table 42: TABLE_DE_NAT_EXTERNAL_IN_PHASE_1
	########################
	ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
		"table=${TABLE_DE_NAT_EXTERNAL_IN_PHASE_1},priority=100,actions=mod_dl_dst=${POD_MAC},goto_table=${TABLE_DE_NAT_EXTERNAL_IN_PHASE_2}"

	########################
	# Table 42: TABLE_DE_NAT_EXTERNAL_IN_PHASE_2
	########################
	ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
		"table=${TABLE_DE_NAT_EXTERNAL_IN_PHASE_2},priority=100,icmp,actions=ct(zone=1,nat),goto_table:${TABLE_EGRESS_LOCAL_POD}"


	########################
	# Table 50: Egress to Local Pods
	########################
	# 	i. Allow traffic to same VNI
	# ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	# 	"table=${TABLE_EGRESS_LOCAL_POD},priority=100,ip,reg0=${VNID},nw_dst=${POD_IP},actions=output:${POD_PORT}"
	# # ARP
	# ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	# 	"table=${TABLE_EGRESS_LOCAL_POD},priority=100,arp,reg0=${VNID},nw_dst=${POD_IP},actions=output:${POD_PORT}"

	# 	***** BUG **** this rule should match on ip_dst but does not eventhough wireshark shows the nw_dst to be 10.1.1.2
	# we can get around this issue by comparing MACs. in that case packet gets to pod just fine. 
	ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
		"table=${TABLE_EGRESS_LOCAL_POD},priority=100,ip,nw_dst=${POD_IP},actions=output:${POD_PORT}"
	# ARP
	ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
		"table=${TABLE_EGRESS_LOCAL_POD},priority=100,arp,nw_dst=${POD_IP},actions=output:${POD_PORT}"

	ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
		"table=${TABLE_EGRESS_LOCAL_POD},priority=50,dl_dst=${POD_MAC},actions=output:${POD_PORT}"

	ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
		"table=${TABLE_EGRESS_LOCAL_POD},priority=1,ip,actions=output:${POD_PORT}"

	# Allow traffic to other VNIs if policy allows
	# TBD
}


del_flows(){

	########################
	# 15. VNI Tag in REG0 (Table 15)
	########################
	#  could also delete based on port: in_port=${POD_PORT}
	ovs-ofctl -O OpenFlow13 del-flows $OVS_BRIDGE "table=${TABLE_INGRESS_HOST_POD},ip,nw_src=${POD_IP}"
	# ARP
	ovs-ofctl -O OpenFlow13 del-flows $OVS_BRIDGE "table=${TABLE_INGRESS_HOST_POD},arp,nw_src=${POD_IP}"

	########################
	# Table 50: Egress to Local Pods
	########################
	# 	i. Allow traffic to same VNI
	ovs-ofctl -O OpenFlow13 del-flows $OVS_BRIDGE "table=${TABLE_EGRESS_LOCAL_POD},ip,nw_dst=${POD_IP}"
	# ARP
	ovs-ofctl -O OpenFlow13 del-flows $OVS_BRIDGE "table=${TABLE_EGRESS_LOCAL_POD},arp,nw_dst=${POD_IP}"

	# Allow traffic to other VNIs if policy allows
	# TBD
}

case "$CMD" in
	add)
		add_flows
		;;
	del)
		del_flows
		;;
	*)
		echo "Invalid cmd: $@"
		exit 1
	esac
