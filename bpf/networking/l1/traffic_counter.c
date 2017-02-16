#ifndef __L1_H_
#define __L1_H_

// #include <netdev_config.h>

#include <bpf/api.h>

#include <stdint.h>
#include <stdio.h>

#include "lib/common.h"
#include "lib/csum.h"
#include "lib/ipv4.h"
#include "lib/l4.h"
#include "lib/dbg.h"
#include "lib/eth.h"
#include "l1.h"

struct l1map_key {
  __be32 address;
} __attribute__((packed));

struct l1map_value {
  __u16 txcount;
  __u16 rxcount;
} __attribute__((packed));

#define L1_MAP_MAX_ENTRIES 4

__BPF_MAP(MAP_NAME, BPF_MAP_TYPE_HASH, 0,
    sizeof(struct l1map_key), sizeof(struct l1map_value),
    PIN_GLOBAL_NS, L1_MAP_MAX_ENTRIES);

// count_ingress_pkts() will count packets destinted (daddr) for the ip address stored in the map above. For example, you can insert an entry in the map where key = container ip and this will count all packets received by the container. 
static inline int count_pkts(struct __sk_buff *skb)
{

  void *data = (void *) (long) skb->data;
  void *data_end = (void *) (long) skb->data_end;
  struct l1map_key key = {};
  struct l1map_value *value;
  struct ethhdr *eth = data;
  struct iphdr *ip = data + ETH_HLEN;
  struct l1map_value init_val = {
    .txcount = 0,
    .rxcount = 0,
  };

  if (data + ETH_HLEN + sizeof(*ip) > data_end)
    return DROP_INVALID;

  regulus_trace_capture(skb, DBG_CAPTURE_FROM_NETDEV, skb->ingress_ifindex);

  key.address = CONTAINER_IP;
  value = map_lookup_elem(&MAP_NAME, &key);
  if (value) {
    if (ip->daddr == CONTAINER_IP){
      // NOTE(awander): bpf is attach to the external veth (ve) and NOT the internal veth (vi); the result is that ingress/egress are reversed. 
      // Traffic from host egresses the ve and ingresses the vi. In order to see these packets, bpf must be attached to the egress of the ve (tc ... egress)
      // ------              ------ 
      // | vi | (i) <--  (e) | ve | 
      // ------           |  ------ 
      //                 bpf
      regulus_trace(skb, DBG_GENERIC, value->rxcount,ip->daddr); 
      value->rxcount = value->rxcount + 1;
    }
    else if (ip->saddr == CONTAINER_IP) {
      // From a container's perspective, traffic that is egressing through the vi will be ingressing to ve (visa versa).
      // In order to see these packets, bpf must be attached to the ingress of the ve (tc ... ingress)
      // ------              ------ 
      // | vi | (e) -->  (i) | ve | 
      // ------           |  ------ 
      //                 bpf
      regulus_trace(skb, DBG_GENERIC, value->txcount,ip->daddr); 
      value->txcount = value->txcount + 1; 
    }
  }
  else{
    regulus_trace(skb, DBG_GENERIC, 0x9999, 0x0); 
    map_update_elem(&MAP_NAME, &key, &init_val, BPF_ANY);
  }

  return TC_ACT_OK;
}

__section("from-netdev")
int from_netdev(struct __sk_buff *skb)
{
  int ret;

  switch (skb->protocol) {
  case __constant_htons(ETH_P_IP):
    ret = count_pkts(skb);
    break;
  default:
    /* Pass unknown traffic to the stack */
    return TC_ACT_OK;
  }

  return TC_ACT_OK;
}

BPF_LICENSE("GPL");


#endif /* __L1_H_ */


