#!/bin/bash
set -e

CMD=$1
COOKIE=$2
POD_IP=$3
PEER_IP=$4
PROTO=$5
PROTO_PORT=$6
POD_PORT=$7

OVS_BRIDGE=ovs-br

# TABLES
TABLE_CLASSIFY="0"
TABLE_ACL="17"
TABLE_ROUTER="40"
TABLE_EGRESS_LOCAL_POD="50"


to_me_flows(){

	########################
	# Table 17: ACL
	########################
	# egress traffic to remote pod
	echo "table=${TABLE_ACL},cookie=0x${COOKIE},priority=200,ct_state=+est,tcp,nw_src=${POD_IP},nw_dst=${PEER_IP},tp_src=${PROTO_PORT},actions=goto_table:${TABLE_ROUTER}"


	########################
	# Table 50: Egress to Local Pods
	########################
	# tcp: 
	# ingress traffic from remote pod ((ON THE SAME HOST)) (2)
	echo "table=${TABLE_EGRESS_LOCAL_POD},cookie=0x${COOKIE},priority=200,ct_state=+new,tcp,nw_dst=${POD_IP},nw_src=${PEER_IP},tp_dst=${PROTO_PORT},actions=ct(commit),${POD_PORT}"
	echo "table=${TABLE_EGRESS_LOCAL_POD},cookie=0x${COOKIE},priority=200,ct_state=+est,tcp,nw_dst=${POD_IP},nw_src=${PEER_IP},tp_dst=${PROTO_PORT},actions=${POD_PORT}"

	# ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	# 	"table=${TABLE_EGRESS_LOCAL_POD},priority=100,tcp,nw_dst=${POD_IP},nw_src=${PEER_IP},tp_dst=${PROTO_PORT},actions=output:${POD_PORT}"

}


from_peer_flows(){

	########################
	# Table 17: ACL
	########################
	# allow new connections to destination pod(s)
	# tcp: (1)
	# TO remote pod
	echo "table=${TABLE_ACL},cookie=0x${COOKIE},priority=200,ct_state=+new,tcp,nw_src=${POD_IP},nw_dst=${PEER_IP},actions=ct(commit),goto_table:${TABLE_ROUTER}"
	echo "table=${TABLE_ACL},cookie=0x${COOKIE},priority=300,ct_state=+est,tcp,nw_src=${POD_IP},nw_dst=${PEER_IP},actions=goto_table:${TABLE_ROUTER}"

	########################
	# Table 50: Egress to Local Pods
	########################
	# tcp: (4)
	# FROM remote pod ((ON THE SAME HOST))
	echo "table=${TABLE_EGRESS_LOCAL_POD},cookie=0x${COOKIE},priority=200,ct_state=+est,tcp,nw_dst=${POD_IP},nw_src=${PEER_IP},actions=${POD_PORT}"
	echo "table=${TABLE_EGRESS_LOCAL_POD},cookie=0x${COOKIE},priority=200,ct_state=+rel,tcp,nw_dst=${POD_IP},nw_src=${PEER_IP},actions=${POD_PORT}"

	# Allow related ICMP packets
	echo "table=${TABLE_EGRESS_LOCAL_POD},cookie=0x${COOKIE},priority=200,ct_state=+rel,icmp,nw_dst=${POD_IP},nw_src=${PEER_IP},actions=${POD_PORT}"

	# ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	# 	"table=${TABLE_EGRESS_LOCAL_POD},priority=100,tcp,nw_dst=${POD_IP},nw_src=${PEER_IP},actions=output:${POD_PORT}"
}

# NOTE(awander): not using conntrack on the "to" side; only on "from"
udp_to_me_flows(){

	########################
	# Table 17: ACL
	########################
	# egress traffic to remote pod
	# we allows this traffic to go through; if it is not return traffic then it should be filtered at the dest using conntrack
	# (3)
	echo "table=${TABLE_ACL},cookie=0x${COOKIE},priority=200,udp,nw_src=${POD_IP},nw_dst=${PEER_IP},tp_src=${PROTO_PORT},actions=goto_table:${TABLE_ROUTER}"
	# echo "table=${TABLE_ACL},cookie=0x${COOKIE},priority=200,icmp,nw_src=${POD_IP},nw_dst=${PEER_IP},actions=goto_table:${TABLE_ROUTER}"

	########################
	# Table 50: Egress to Local Pods
	########################
	# (2)
	echo "table=${TABLE_EGRESS_LOCAL_POD},cookie=0x${COOKIE},priority=100,udp,nw_dst=${POD_IP},nw_src=${PEER_IP},tp_dst=${PROTO_PORT},actions=output:${POD_PORT}"
	# we allow *all* icmp messages
	# echo "table=${TABLE_EGRESS_LOCAL_POD},cookie=0x${COOKIE},priority=100,icmp,nw_src=${PEER_IP},tp_dst=${PROTO_PORT},actions=output:${POD_PORT}"

	# TODO(awander): if vnid is specified, we only need a single rule at TABLE_EGRESS_LOCAL_POD instead of one for each PEER_IP
	# we could do this by checking if vnid is present, if so, we drop the nw_src=${PEER_IP} check and use VNID. 
}

udp_from_peer_flows(){

	########################
	# Table 17: ACL
	########################
	# allow new connections to destination pod(s)
	# TO remote pod 
	# (1)
	echo "table=${TABLE_ACL},cookie=0x${COOKIE},priority=200,ct_state=+new,udp,nw_src=${POD_IP},nw_dst=${PEER_IP},actions=ct(commit),goto_table:${TABLE_ROUTER}"
	# (5)
	echo "table=${TABLE_ACL},cookie=0x${COOKIE},priority=300,ct_state=+est,udp,nw_src=${POD_IP},nw_dst=${PEER_IP},actions=goto_table:${TABLE_ROUTER}"
	# allow icmp
	# echo "table=${TABLE_ACL},cookie=0x${COOKIE},priority=300,ct_state=+rel,icmp,nw_src=${POD_IP},nw_dst=${PEER_IP},actions=goto_table:${TABLE_ROUTER}"

	########################
	# Table 50: Egress to Local Pods
	########################
	# (4)
	echo "table=${TABLE_EGRESS_LOCAL_POD},cookie=0x${COOKIE},priority=100,ct_state=+est,udp,nw_dst=${POD_IP},nw_src=${PEER_IP},actions=output:${POD_PORT}"
	# Allow related ICMP packets
	# echo "table=${TABLE_EGRESS_LOCAL_POD},cookie=0x${COOKIE},priority=200,ct_state=+rel,icmp,nw_dst=${POD_IP},nw_src=${PEER_IP},actions=goto_table:${TABLE_ROUTER}"

}


# del_flows(){
# 	# delete flows with cookies that exactly match
# 	ovs-ofctl -O OpenFlow13 del-flows $OVS_BRIDGE "cookie=0x${COOKIE}/-1"
# }

# delete all flows associated with Policy 
# the script should be executed as part of an ovs automic (--bundle) operatoin.

case "$CMD" in
	to_me)
		to_me_flows
		;;
	from_peer)
		from_peer_flows
		;;
	# del)
	# 	del_flows
	# 	;;
	*)
		echo "Invalid cmd: $@"
		exit 1
	esac
