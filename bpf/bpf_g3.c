
#include <netdev_config.h>

#include <bpf/api.h>

#include <stdint.h>
#include <stdio.h>

#include "lib/common.h"
#include "lib/csum.h"
// #include "lib/ipv4.h"
// #include "lib/maps.h"
// #include "lib/ipv6.h"
// #include "lib/l4.h"
// #include "lib/eth.h"
// #include "lib/dbg.h"
// #include "lib/drop.h"
// #include "lib/lb.h"


static inline int handle_ipv4(struct __sk_buff *skb)
{

	void *data = (void *) (long) skb->data;
	void *data_end = (void *) (long) skb->data_end;
	struct g3map_key key = {};
	struct g3map_value *svc;
	struct iphdr *ip = data + ETH_HLEN;
	struct csum_offset csum_off = {};
	int l3_off, l4_off, ret;
	__be32 new_dst;
	__u8 nexthdr;
	__u16 slave;

	if (data + ETH_HLEN + sizeof(*ip) > data_end)
		return DROP_INVALID;

	// TODO(awander): how does trace work?
	// cilium_trace_capture(skb, DBG_CAPTURE_FROM_LB, skb->ingress_ifindex);

	nexthdr = ip->protocol;
	key.address = ip->daddr;
	l3_off = ETH_HLEN;
	l4_off = ETH_HLEN + (ip->ihl * 4); // ipv4_hdrlen(ip);
	csum_l4_offset_and_flags(nexthdr, &csum_off);


	// svc = lb4_lookup_service(skb, &key);
	// if (svc == NULL) {
	// 	/* Pass packets to the stack which should not be loadbalanced */
	// 	return TC_ACT_OK;
	// }
	// slave = lb_select_slave(skb, svc->count);
	// if (!(svc = lb4_lookup_slave(skb, &key, slave)))
	// 	return DROP_NO_SERVICE;

	// new_dst = svc->target;
	// ret = lb4_xlate(skb, &new_dst, nexthdr, l3_off, l4_off, &csum_off, &key, svc);
	// if (IS_ERR(ret))
	// 	return ret;
	// return TC_ACT_REDIRECT;

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

	// if (IS_ERR(ret))
	// 	return send_drop_notify_error(skb, ret, TC_ACT_SHOT);
// #ifdef LB_REDIRECT
// 	if (ret == TC_ACT_REDIRECT) {
// 		int ifindex = LB_REDIRECT;
// #ifdef LB_DSTMAC
// 		union macaddr mac = LB_DSTMAC;

// 		if (eth_store_daddr(skb, (__u8 *) &mac.addr, 0) < 0)
// 			ret = DROP_WRITE_ERROR;
// #endif
// 		cilium_trace_capture(skb, DBG_CAPTURE_DELIVERY, ifindex);
// 		return redirect(ifindex, 0);
// 	}
// #endif
// 	cilium_trace_capture(skb, DBG_CAPTURE_DELIVERY, 0);

	return TC_ACT_OK;
}

BPF_LICENSE("GPL");
