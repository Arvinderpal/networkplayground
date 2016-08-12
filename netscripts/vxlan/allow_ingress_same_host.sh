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
