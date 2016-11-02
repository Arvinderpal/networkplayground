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


tcp_to_me_flows(){

	########################
	# Table 17: ACL
	########################
	# allow connections from destination pod(s)

	# tcp
	# ingress traffic from remote pod (2)
	echo "table=${TABLE_ACL},cookie=0x${COOKIE},priority=200,ct_state=+new,tcp,nw_dst=${POD_IP},nw_src=${PEER_IP},tp_dst=${PROTO_PORT},actions=ct(commit),goto_table:${TABLE_ROUTER}"
	echo "table=${TABLE_ACL},cookie=0x${COOKIE},priority=200,ct_state=+est,tcp,nw_dst=${POD_IP},nw_src=${PEER_IP},tp_dst=${PROTO_PORT},actions=goto_table:${TABLE_ROUTER}"

	# egress traffic to remote pod
	echo "table=${TABLE_ACL},cookie=0x${COOKIE},priority=200,ct_state=+est,tcp,nw_src=${POD_IP},nw_dst=${PEER_IP},tp_src=${PROTO_PORT},actions=goto_table:${TABLE_ROUTER}"

	########################
	# Table 50: Egress to Local Pods
	########################
	# tcp: 
	echo "table=${TABLE_EGRESS_LOCAL_POD},cookie=0x${COOKIE},priority=100,tcp,nw_dst=${POD_IP},nw_src=${PEER_IP},tp_dst=${PROTO_PORT},actions=output:${POD_PORT}"

}


tcp_from_peer_flows(){

	########################
	# Table 17: ACL
	########################
	# allow new connections to destination pod(s)
	# tcp: (1)
	# TO remote pod
	echo "table=${TABLE_ACL},cookie=0x${COOKIE},priority=200,ct_state=+new,tcp,nw_src=${POD_IP},nw_dst=${PEER_IP},actions=ct(commit),goto_table:${TABLE_ROUTER}"
	echo "table=${TABLE_ACL},cookie=0x${COOKIE},priority=300,ct_state=+est,tcp,nw_src=${POD_IP},nw_dst=${PEER_IP},actions=goto_table:${TABLE_ROUTER}"

	# FROM remote pod
	# ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	# 	"table=${TABLE_ACL},priority=200,ct_state=+new,tcp,nw_dst=${POD_IP},nw_src=${PEER_IP},actions=goto_table:${TABLE_ROUTER}"
	# ovs-ofctl -O OpenFlow13 add-flow $OVS_BRIDGE \
	# 	"table=${TABLE_ACL},priority=200,ct_state=-est,tcp,nw_dst=${POD_IP},nw_src=${PEER_IP},actions=ct(table=${TABLE_CLASSIFY})"
	echo "table=${TABLE_ACL},cookie=0x${COOKIE},priority=200,ct_state=+est,tcp,nw_dst=${POD_IP},nw_src=${PEER_IP},actions=goto_table:${TABLE_ROUTER}"
	echo "table=${TABLE_ACL},cookie=0x${COOKIE},priority=200,ct_state=+rel,tcp,nw_dst=${POD_IP},nw_src=${PEER_IP},actions=goto_table:${TABLE_ROUTER}"

	# Allow related ICMP packets
	echo "table=${TABLE_ACL},cookie=0x${COOKIE},priority=200,ct_state=+rel,icmp,nw_dst=${POD_IP},nw_src=${PEER_IP},actions=goto_table:${TABLE_ROUTER}"

	########################
	# Table 50: Egress to Local Pods
	########################
	# tcp: (4)
	echo "table=${TABLE_EGRESS_LOCAL_POD},cookie=0x${COOKIE},priority=100,tcp,nw_dst=${POD_IP},nw_src=${PEER_IP},actions=output:${POD_PORT}"

}

# NOTE(awander): not using conntrack on the "to" side; only on "from"
udp_to_me_flows(){

	########################
	# Table 17: ACL
	########################
	# ingress traffic from remote pod:
	# NOTE(awander): this is a duplicate of TABLE_EGRESS_LOCAL_POD rule below. It is tempting to remove this rule . This would require
	# a generic nw_dst=${CLUSTER_SUBNET} rule for all in TABLE_ACL; however, this would allow traffic to egress to internet from any pod; return 
	# traffic would be dropped, but traffic would still go out - this is a security concern. 
	# (2)
	echo "table=${TABLE_ACL},cookie=0x${COOKIE},priority=200,udp,nw_dst=${POD_IP},nw_src=${PEER_IP},tp_dst=${PROTO_PORT},actions=goto_table:${TABLE_ROUTER}"	
	# we allow *all* icmp messages
	# echo "table=${TABLE_ACL},cookie=0x${COOKIE},priority=200,icmp,nw_src=${PEER_IP},tp_dst=${PROTO_PORT},actions=goto_table:${TABLE_ROUTER}"

	# egress traffic to remote pod
	# we allows this traffic to go through; if it is not return traffic then it should be filtered at the dest using conntrack
	# (4)
	echo "table=${TABLE_ACL},cookie=0x${COOKIE},priority=200,udp,nw_src=${POD_IP},nw_dst=${PEER_IP},tp_src=${PROTO_PORT},actions=goto_table:${TABLE_ROUTER}"
	# echo "table=${TABLE_ACL},cookie=0x${COOKIE},priority=200,icmp,nw_src=${POD_IP},nw_dst=${PEER_IP},actions=goto_table:${TABLE_ROUTER}"

	########################
	# Table 50: Egress to Local Pods
	########################
	# (3)
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
	# (7)
	echo "table=${TABLE_ACL},cookie=0x${COOKIE},priority=300,ct_state=+est,udp,nw_src=${POD_IP},nw_dst=${PEER_IP},actions=goto_table:${TABLE_ROUTER}"
	# allow icmp
	# echo "table=${TABLE_ACL},cookie=0x${COOKIE},priority=300,ct_state=+rel,icmp,nw_src=${POD_IP},nw_dst=${PEER_IP},actions=goto_table:${TABLE_ROUTER}"

	# FROM remote pod
	# (5)
	echo "table=${TABLE_ACL},cookie=0x${COOKIE},priority=200,ct_state=+est,udp,nw_dst=${POD_IP},nw_src=${PEER_IP},actions=goto_table:${TABLE_ROUTER}"
	# echo "table=${TABLE_ACL},cookie=0x${COOKIE},priority=200,ct_state=+rel,udp,nw_dst=${POD_IP},nw_src=${PEER_IP},actions=goto_table:${TABLE_ROUTER}"

	# Allow related ICMP packets
	# echo "table=${TABLE_ACL},cookie=0x${COOKIE},priority=200,ct_state=+rel,icmp,nw_dst=${POD_IP},nw_src=${PEER_IP},actions=goto_table:${TABLE_ROUTER}"

	########################
	# Table 50: Egress to Local Pods
	########################
	# (6)
	echo "table=${TABLE_EGRESS_LOCAL_POD},cookie=0x${COOKIE},priority=100,udp,nw_dst=${POD_IP},nw_src=${PEER_IP},actions=output:${POD_PORT}"
}

# delete flows with cookies that exactly match
echo delete "cookie=0x${COOKIE}/-1"

case "$PROTO" in
	tcp)
		case "$CMD" in
			to_me)
				tcp_to_me_flows
				;;
			from_peer)
				tcp_from_peer_flows
				;;
			*)
				echo "Invalid cmd: $@"
				exit 1
			esac
	;;
	udp)
		case "$CMD" in
			to_me)
				udp_to_me_flows
				;;
			from_peer)
				udp_from_peer_flows
				;;
			*)
				echo "Invalid cmd: $@"
				exit 1
			esac
	;;
	# icmp)
	*)
		echo "Invalid protocol: $@"
		exit 1
	esac
