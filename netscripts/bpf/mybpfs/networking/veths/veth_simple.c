
#include <bcc/proto.h>

struct ifindex_leaf_t {
  u64 tx_pkts;
  u64 tx_bytes;
  u64 rx_pkts;
  u64 rx_bytes;
};

// maintains per interface counts of the number of pkts tx
BPF_TABLE("hash", u64, struct ifindex_leaf_t, state, 4096);

int veth_tx(struct __sk_buff *skb){
  u8 *cursor = 0;
  ethernet: {
    struct ethernet_t *ethernet = cursor_advance(cursor, sizeof(*ethernet));
    u64 src_mac = ethernet->src;
    struct ifindex_leaf_t *leaf = state.lookup(&src_mac);
    if (leaf) {
      lock_xadd(&leaf->tx_pkts, 1);
      lock_xadd(&leaf->tx_bytes, skb->len);
      // bpf_skb_vlan_push(skb, leaf->vlan_proto, leaf->vlan_tci);
      // bpf_clone_redirect(skb, leaf->out_ifindex, 0);
    }
    else {
      struct ifindex_leaf_t zleaf = {0};
      struct ifindex_leaf_t *new_leaf = data.lookup_or_init(&src_mac, &zleaf);   
      lock_xadd(&new_leaf->tx_pkts, 1);
      lock_xadd(&new_leaf->tx_bytes, skb->len); 	
    }
  }
  return 1;
}

int veth_rx(struct __sk_buff *skb){
  u8 *cursor = 0;
  ethernet: {
    struct ethernet_t *ethernet = cursor_advance(cursor, sizeof(*ethernet));
    u64 dst_mac = ethernet->dst;
    struct ifindex_leaf_t *leaf = data.lookup(&dst_mac);
    if (leaf) {
      lock_xadd(&leaf->rx_pkts, 1);
      lock_xadd(&leaf->rx_bytes, skb->len);
    }
    else {
      struct ifindex_leaf_t zleaf = {0};
      struct ifindex_leaf_t *new_leaf = data.lookup_or_init(&dst_mac, &zleaf);   
      lock_xadd(&new_leaf->rx_pkts, 1);
      lock_xadd(&new_leaf->rx_bytes, skb->len); 	
    }
  }
  return 1;

}