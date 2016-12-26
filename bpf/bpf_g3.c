
#include <netdev_config.h>

#include <bpf/api.h>

#include <stdint.h>
#include <stdio.h>

#include "lib/common.h"
#include "lib/csum.h"
#include "lib/ipv4.h"
// #include "lib/maps.h"
// #include "lib/ipv6.h"
#include "lib/l4.h"
// #include "lib/eth.h"
#include "lib/dbg.h"
// #include "lib/drop.h"
// #include "lib/lb.h"
#include "lib/g3.h"

static inline int handle_ipv4(struct __sk_buff *skb)
{

	void *data = (void *) (long) skb->data;
	void *data_end = (void *) (long) skb->data_end;
	struct g3map_key key = {};
	struct g3map_value *value;
	struct ethhdr *eth = data;
	struct iphdr *ip = data + ETH_HLEN;
	struct csum_offset csum_off = {};
	int l3_off, l4_off, ret;
	__u8 nexthdr;
	__u16 dport = 0; /* important to initialize or verifier complains!*/

	if (data + ETH_HLEN + sizeof(*ip) > data_end)
		return DROP_INVALID;

	// regulus_trace_capture(skb, DBG_CAPTURE_FROM_NETDEV, skb->ingress_ifindex);

	nexthdr = ip->protocol;
	key.address = ip->daddr;
	l3_off = ETH_HLEN;
	l4_off = ETH_HLEN + ipv4_hdrlen(ip); 
	csum_l4_offset_and_flags(nexthdr, &csum_off);

	ret = extract_l4_dport(skb, nexthdr, l4_off, &dport);
	if (IS_ERR(ret)) {
		if (ret == DROP_UNKNOWN_L4) {
			/* Pass unknown L4 to stack */
			return TC_ACT_OK;
		} else
			return ret;
	}

	// regulus_trace(skb, DBG_GENERIC, key.address,ntohs(dport)); 

	// only handle UDP 
	if (nexthdr == IPPROTO_UDP && dport == htons(NATS_SERVER_PORT)){
		__u16 sport = 0;

		// NOTE(awander): i could not do da to L4 hdr... seems like a limitation??
		// struct udphdr *udp = data + l4_off;
		// if (data + l4_off + sizeof(*udp) > data_end)
		// 	return DROP_INVALID;
		// sport = udp->source; 
		ret = extract_l4_sport(skb, nexthdr, l4_off, &sport);
		if (IS_ERR(ret)) {
			if (ret == DROP_UNKNOWN_L4) {
				/* Pass unknown L4 to stack */
				return TC_ACT_OK;
			} else
				return ret;
		}

		regulus_trace_capture(skb, DBG_CAPTURE_FROM_NETDEV, skb->ingress_ifindex);
		value = g3_lookup_value(skb, &key);
		if (value == NULL) {
			/* Pass packets to the stack */
			return TC_ACT_OK;
		}
		value->count = value->count + 1;

		ret = udp_xlate(skb, nexthdr, eth, ip, dport, sport, l3_off, l4_off, &csum_off);
		if (IS_ERR(ret))
			return ret;
		return TC_ACT_REDIRECT;

		// new_dst = svc->target;
		// ret = lb4_xlate(skb, &new_dst, nexthdr, l3_off, l4_off, &csum_off, &key, svc);
		// if (IS_ERR(ret))
		// 	return ret;
		// return TC_ACT_REDIRECT;
	
	}

	// pass the packet to network stack for normal processing
	return TC_ACT_OK;
}
__section("from-netdev")
int from_netdev(struct __sk_buff *skb)
{
	int ret;

	switch (skb->protocol) {
	case __constant_htons(ETH_P_IP):
		ret = handle_ipv4(skb);
		break;

	default:
		/* Pass unknown traffic to the stack */
		return TC_ACT_OK;
	}

	// TODO(awwander): we need add error handling:
	// e.g. if an error occurs while modifying the pkt,
	// we should drop the pkt (with its dirty skb) and 
	// terminate the BPF. 
	// if (IS_ERR(ret))
	// 	return send_drop_notify_error(skb, ret, TC_ACT_SHOT);

	if (ret == TC_ACT_REDIRECT) {
		// int ifindex = LB_REDIRECT;
		// #ifdef LB_DSTMAC
		// 		union macaddr mac = LB_DSTMAC;

		// 		if (eth_store_daddr(skb, (__u8 *) &mac.addr, 0) < 0)
		// 			ret = DROP_WRITE_ERROR;
		// #endif
		regulus_trace_capture(skb, DBG_CAPTURE_DELIVERY, skb->ifindex);
		return  redirect(skb->ifindex, 0);
		// bpf_clone_redirect(skb, skb->ifindex, 0 /*egress*/);
 	}

	return TC_ACT_OK;
}

BPF_LICENSE("GPL");
