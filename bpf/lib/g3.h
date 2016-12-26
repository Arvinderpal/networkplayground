/*
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 */


#ifndef __G3_H_
#define __G3_H_

// #include "csum.h"
#include "eth.h"

/* FIXME: Make configurable */
// should be in sync with const.go
#define REGULUS_G3MAP_MAX_ENTRIES	65535

// TODO(awander): NATS default port is 4222, but this is configurable
#define NATS_SERVER_PORT  0x107E 

__BPF_MAP(regulus_g3, BPF_MAP_TYPE_HASH, 0,
	  sizeof(struct g3map_key), sizeof(struct g3map_value),
	  PIN_GLOBAL_NS, REGULUS_G3MAP_MAX_ENTRIES);


static inline struct g3map_value *g3_lookup_value(struct __sk_buff *skb,
						     struct g3map_key *key)
{
	struct g3map_value *value;

	value = map_lookup_elem(&regulus_g3, key);
	if (value){
		// regulus_trace(skb, DBG_GENERIC, key->address, value->count); 
		return value;
	}

	// cilium_trace(skb, DBG_LB4_LOOKUP_MASTER_FAIL, 0, 0);
	return NULL;
}

static inline int __inline__ extract_l4_dport(struct __sk_buff *skb, __u8 nexthdr,
					     int l4_off, __u16 *port)
{
	int ret;

	switch (nexthdr) {
	case IPPROTO_TCP:
	case IPPROTO_UDP:
		/* Port offsets for UDP and TCP are the same */
		// NOTE (awander): i don't think we have DA to L4 hdr
		// so use of skb_load_bytes is necessary...
		ret = l4_load_port(skb, l4_off + TCP_DPORT_OFF, port);
		if (IS_ERR(ret))
			return ret;
		break;

	case IPPROTO_ICMPV6:
	case IPPROTO_ICMP:
		break;

	default:
		/* Pass unknown L4 to stack */
		return DROP_UNKNOWN_L4;
	}

	return 0;
}


static inline int __inline__ extract_l4_sport(struct __sk_buff *skb, __u8 nexthdr,
					     int l4_off, __u16 *port)
{
	int ret;

	switch (nexthdr) {
	case IPPROTO_TCP:
	case IPPROTO_UDP:
		/* Port offsets for UDP and TCP are the same */
		// NOTE (awander): i don't think we have DA to L4 hdr
		// so use of skb_load_bytes is necessary...
		ret = l4_load_port(skb, l4_off + TCP_SPORT_OFF, port);
		if (IS_ERR(ret))
			return ret;
		break;

	case IPPROTO_ICMPV6:
	case IPPROTO_ICMP:
		break;

	default:
		/* Pass unknown L4 to stack */
		return DROP_UNKNOWN_L4;
	}

	return 0;
}


static inline int udp_xlate(struct __sk_buff *skb, __u8 nexthdr,struct ethhdr *eth, struct iphdr *ip, __u16 dport, __u16 sport, int l3_off, int l4_off, struct csum_offset *csum_off)
{
	int ret;
	// __be32 sum;

	/* ETH */
	union macaddr smac = *(union macaddr *) &eth->h_source;
	union macaddr dmac = *(union macaddr *) &eth->h_dest;
	/* IP */
	__be32 dip = ip->daddr;
	__be32 sip = ip->saddr;


	/* ETH */
	if (eth_store_saddr(skb, dmac.addr, 0) < 0 ||
	    eth_store_daddr(skb, smac.addr, 0) < 0)
	    return DROP_WRITE_ERROR;
	/* IP */
	ret = skb_store_bytes(skb, l3_off + offsetof(struct iphdr, daddr), &sip, 4, 0);
	if (ret < 0)
		return DROP_WRITE_ERROR;
	ret = skb_store_bytes(skb, l3_off + offsetof(struct iphdr, saddr), &dip, 4, 0);
	if (ret < 0)
		return DROP_WRITE_ERROR;

	// TODO(awander): if we swap src/dst ips then the csum not change, right?
	// sum = csum_diff(&key->address, 4, new_addr, 4, 0);
	// if (l3_csum_replace(skb, l3_off + offsetof(struct iphdr, check), 0, sum, 0) < 0)
	// 	return DROP_CSUM_L3;
	// TODO(awander): udp/tcp csum also uses ip fields
	// https://en.wikipedia.org/wiki/User_Datagram_Protocol
	// hopefully, we don't need to touch this:
	// if (csum_off->offset) {
	// 	if (csum_l4_replace(skb, l4_off, csum_off, 0, sum, BPF_F_PSEUDO_HDR) < 0)
	// 		return DROP_CSUM_L4;
	// }

	/* UDP */		
	// TODO(awander): not sure if we need the csum calculation:
	if (nexthdr == IPPROTO_UDP) {
		ret = l4_modify_port(skb, l4_off, UDP_DPORT_OFF, csum_off, sport, dport);
		if (IS_ERR(ret))
			return ret;
		ret = l4_modify_port(skb, l4_off, UDP_SPORT_OFF, csum_off, dport, sport);
		if (IS_ERR(ret))
			return ret;
}
	return TC_ACT_OK;
}


#endif /* __G3_H_ */