#include <uapi/linux/bpf.h>
#include <uapi/linux/if_ether.h>
#include <uapi/linux/if_packet.h>
#include <uapi/linux/ip.h>
#include <uapi/linux/in.h>
#include <uapi/linux/udp.h>
#include <bcc/proto.h>

#define ETH_LEN 14

struct dns_hdr_t
{
    uint16_t id;
    uint16_t flags;
    /* number of entries in the question section */
    uint16_t qdcount;
    /* number of resource records in the answer section */
    uint16_t ancount;
    /* number of name server resource records in the authority records section*/
    uint16_t nscount;
    /* number of resource records in the additional records section */
    uint16_t arcount;
} BPF_PACKET_HEADER;

struct dns_query_t
{
    unsigned char *name;
    unsigned short qtype;
    unsigned short qclass;
} BPF_PACKET_HEADER;

struct dns_char_t
{
    char c;
} BPF_PACKET_HEADER;


struct Key {
  u32 src_ip;
  u16 id;
  u8 pad[2];
};

struct Leaf {
  unsigned char p[32];
};

BPF_TABLE("hash", struct Key, struct Leaf, incoming, 1024);

int dns_record(struct __sk_buff *skb)
{ 
    u8 *cursor = 0;
    u32 len = 0;
    struct Key key = {};
    struct Leaf zLeaf = {};
    struct ethernet_t *ethernet = cursor_advance(cursor, sizeof(*ethernet));
    
    if(ethernet->type == ETH_P_IP) {

      struct ip_t *ip = cursor_advance(cursor, sizeof(*ip));
      u16 hlen_bytes = ip->hlen << 2;
      cursor_advance(cursor, hlen_bytes - sizeof(*ip));
      
      if(ip->nextp == IPPROTO_UDP) {
      	bpf_trace_printk("IP UDP packet received \r\n");
        
        // Add Key just for now based on src_ip and ip id.
        key.src_ip = ip->src;
        key.id = ip->identification;

        struct udp_t *udp = cursor_advance(cursor, sizeof(*udp));
        if(udp->dport == 53){
          bpf_trace_printk("DNS packet received \r\n");
          
          u8 *sentinel = cursor + udp->length - sizeof(*udp);
          struct dns_hdr_t *dns_hdr = cursor_advance(cursor, sizeof(*dns_hdr));
          if((dns_hdr->flags >>15) != 0) {
            // Exit if this packet is not a request.
            return 0;
          }
  
          bpf_trace_printk("DNS Request! \r\n");

          struct Leaf *leaf = incoming.lookup_or_init(&key, &zLeaf);
          u16 i = 0;
          struct dns_char_t *c;
          if (cursor == sentinel) goto end; c = cursor_advance(cursor, 1); leaf->p[i++] = c->c;
          if (cursor == sentinel) goto end; c = cursor_advance(cursor, 1); leaf->p[i++] = c->c;
          if (cursor == sentinel) goto end; c = cursor_advance(cursor, 1); leaf->p[i++] = c->c;
          if (cursor == sentinel) goto end; c = cursor_advance(cursor, 1); leaf->p[i++] = c->c;
          if (cursor == sentinel) goto end; c = cursor_advance(cursor, 1); leaf->p[i++] = c->c;
          if (cursor == sentinel) goto end; c = cursor_advance(cursor, 1); leaf->p[i++] = c->c;
          if (cursor == sentinel) goto end; c = cursor_advance(cursor, 1); leaf->p[i++] = c->c;
          if (cursor == sentinel) goto end; c = cursor_advance(cursor, 1); leaf->p[i++] = c->c;
          if (cursor == sentinel) goto end; c = cursor_advance(cursor, 1); leaf->p[i++] = c->c;
          if (cursor == sentinel) goto end; c = cursor_advance(cursor, 1); leaf->p[i++] = c->c;
          end:
          {}
      }
    }
  }

  return 0;
}