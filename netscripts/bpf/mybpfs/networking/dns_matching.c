/*
 * dns_matching.c  Drop DNS packets requesting DNS name contained in hash map
 *    For Linux, uses BCC, eBPF. See .py file.
 *
 * Copyright (c) 2016 Rudi Floren.
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of version 2 of the GNU General Public
 * License as published by the Free Software Foundation.
 *
 * 11-May-2016  Rudi Floren Created this.
 */

#include <uapi/linux/bpf.h>
#include <uapi/linux/if_ether.h>
#include <uapi/linux/if_packet.h>
#include <uapi/linux/ip.h>
#include <uapi/linux/in.h>
#include <uapi/linux/udp.h>
#include <bcc/proto.h>
#include <uapi/linux/ptrace.h>
#include <net/sock.h>
#include <linux/blkdev.h>
#include <linux/sched.h>

#define ETH_LEN 14

struct dns_hdr_t
{
    uint16_t id;
    uint16_t flags;
    uint16_t qdcount;
    uint16_t ancount;
    uint16_t nscount;
    uint16_t arcount;
} BPF_PACKET_HEADER;


struct dns_query_flags_t
{
  uint16_t qtype;
  uint16_t qclass;
} BPF_PACKET_HEADER;

struct dns_char_t
{
    char c;
} BPF_PACKET_HEADER;

struct Key {
  unsigned char p[32];
};

struct Leaf {
  // Not really needed in this example
  unsigned char p[4];
};

// define output data struct in C
struct output_t {
	unsigned long p[32];
};

BPF_PERF_OUTPUT(events);
BPF_TABLE("hash", struct Key, struct Leaf, cache, 128);


int dns_matching(struct __sk_buff *skb)
{
  u8 *cursor = 0;
  struct Key key = {};
  // Check of ethernet/IP frame.
  struct ethernet_t *ethernet = cursor_advance(cursor, sizeof(*ethernet));
  if(ethernet->type == ETH_P_IP) {

    // Check for UDP.
    struct ip_t *ip = cursor_advance(cursor, sizeof(*ip));
    u16 hlen_bytes = ip->hlen << 2;
    if(ip->nextp == IPPROTO_UDP) {
      bpf_trace_printk("IP UDP packet received \r\n");
      // Check for Port 53, DNS packet.
      struct udp_t *udp = cursor_advance(cursor, sizeof(*udp));
      if(udp->dport == 53){
      	bpf_trace_printk("DNS packet received \r\n");
        // Our Cursor + the length of our udp packet - size of the udp header
        // - the two 16bit values for QTYPE and QCLASS.
        u8 *sentinel = cursor + udp->length - sizeof(*udp) - 4;

        struct dns_hdr_t *dns_hdr = cursor_advance(cursor, sizeof(*dns_hdr));

        // Do nothing if packet is not a request.
        if((dns_hdr->flags >>15) != 0) {
          // Exit if this packet is not a request.
          return -1;
        }
        bpf_trace_printk("DNS Request! \r\n");
        u16 i = 0;
        struct dns_char_t *c;
        // This unroll worked not in latest BCC version.
		// #pragma unroll
  //       for(u8 j = 0; i<255;i++){
  //         if (cursor == sentinel) goto end; c = cursor_advance(cursor, 1); key.p[i++] = c->c;
  //       }
  //       end:
  //       {}
          if (cursor == sentinel) goto end; c = cursor_advance(cursor, 1); key.p[i++] = c->c;
          if (cursor == sentinel) goto end; c = cursor_advance(cursor, 1); key.p[i++] = c->c;
          if (cursor == sentinel) goto end; c = cursor_advance(cursor, 1); key.p[i++] = c->c;
          if (cursor == sentinel) goto end; c = cursor_advance(cursor, 1); key.p[i++] = c->c;
          if (cursor == sentinel) goto end; c = cursor_advance(cursor, 1); key.p[i++] = c->c;
          if (cursor == sentinel) goto end; c = cursor_advance(cursor, 1); key.p[i++] = c->c;
          if (cursor == sentinel) goto end; c = cursor_advance(cursor, 1); key.p[i++] = c->c;
          if (cursor == sentinel) goto end; c = cursor_advance(cursor, 1); key.p[i++] = c->c;
          if (cursor == sentinel) goto end; c = cursor_advance(cursor, 1); key.p[i++] = c->c;
          if (cursor == sentinel) goto end; c = cursor_advance(cursor, 1); key.p[i++] = c->c;
          end:
          {}
        struct Leaf * lookup_leaf = cache.lookup(&key);

        // If DNS name is contained in our map, drop packet.
        if(lookup_leaf) {
          bpf_trace_printk("Hit foo.bar! \r\n");
          return 0;
        }
      }
    }
  }

  return -1;
}


int dns_matching_3(struct __sk_buff *skb)
{
  u8 *cursor = 0;
  struct Key key = {};
  // Check of ethernet/IP frame.
  struct ethernet_t *ethernet = cursor_advance(cursor, sizeof(*ethernet));
  if(ethernet->type == ETH_P_IP) {

  	// bpf_trace_printk("ETH IP packet received \r\n");

    // Check for UDP.
    struct ip_t *ip = cursor_advance(cursor, sizeof(*ip));
    u16 hlen_bytes = ip->hlen << 2;
    if(ip->nextp == IPPROTO_UDP) {

      bpf_trace_printk("IP UDP packet received \r\n");

      // Check for Port 53, DNS packet.
      struct udp_t *udp = cursor_advance(cursor, sizeof(*udp));
      if(udp->dport == 53){

		bpf_trace_printk("DNS packet received \r\n");

        // Our Cursor + the length of our udp packet - size of the udp header
        // - the two 16bit values for QTYPE and QCLASS.
        u8 *sentinel = cursor + udp->length - sizeof(*udp) - 4;

        struct dns_hdr_t *dns_hdr = cursor_advance(cursor, sizeof(*dns_hdr));

        // Do nothing if packet is not a request.
        if((dns_hdr->flags >>15) != 0) {
          // Exit if this packet is not a request.
          return -1;
        }

        bpf_trace_printk("DNS Request! \r\n");

		// //load firt 7 byte of payload into p (payload_array)
		// //direct access to skb not allowed
		// unsigned long p[7];
		// int i = 0;
		// int j = 0;
		// for (i = payload_offset ; i < (payload_offset + 7) ; i++) {
		// 	p[j] = load_byte(skb , i);
		// 	j++;
		// }

        u16 i = 0;
        struct dns_char_t *c;
        // This unroll worked not in latest BCC version.
        for(; i<7;i++){
          // if (cursor == sentinel) {
          // 	goto end; 
          // }
          c = cursor_advance(cursor, 1); 
          key.p[i++] = c->c;
        }
        end:
        {}
		
		bpf_trace_printk("Length: %d \r\n", i);
        for(u16 x=0; x < i; x++){
        	// bpf_trace_printk("%hhX", key.p[x]);
        	// bpf_trace_printk("x");
        }
        bpf_trace_printk("\r\n");

        struct Leaf * lookup_leaf = cache.lookup(&key);

        // If DNS name is contained in our map, drop packet.
        if(lookup_leaf) {
          return 0;
        }
      }
    }
  }

  return -1;
}


int dns_matching_2(struct __sk_buff *skb)
{
	u8 *cursor = 0;
	struct Key key = {};
	
	struct ethernet_t *ethernet = cursor_advance(cursor, sizeof(*ethernet));
	//filter IP packets (ethernet type = 0x0800)
	if (!(ethernet->type == 0x0800)) {
		goto SKIP;	
	}

	struct ip_t *ip = cursor_advance(cursor, sizeof(*ip));
	//filter TCP packets (ip next protocol = 0x06)
	if (ip->nextp != IPPROTO_UDP) {
		goto SKIP;
	}

	u32  udp_header_length = 0;
	u32  ip_header_length = 0;
	u32  payload_offset = 0;
	u32  payload_length = 0;

	struct udp_t *udp = cursor_advance(cursor, sizeof(*udp));

	if(udp->dport == 53){

		bpf_trace_printk("DNS packet received \r\n");

		//calculate ip header length
		//value to multiply * 4
		//e.g. ip->hlen = 5 ; IP Header Length = 5 x 4 byte = 20 byte
		ip_header_length = ip->hlen << 2;    //SHL 2 -> *4 multiply
			
		//calculate udp header length
		// https://en.wikipedia.org/wiki/User_Datagram_Protocol
		// consists of 4 fields, each 16-bits long
		//value to multiply *4
		//e.g. udp->offset = 5 ; UDP Header Length = 5 x 4 byte = 20 byte
		// udp_header_length = udp->offset << 2; //SHL 2 -> *4 multiply
		udp_header_length = 4 << 1; 

		//calculate patload offset and length
		payload_offset = ETH_HLEN + ip_header_length + udp_header_length; 
		payload_length = ip->tlen - ip_header_length - udp_header_length;

		bpf_trace_printk("Payload Length: %d \r\n", payload_length);

		if(payload_length < 7) {
			goto SKIP;
		}

		//load firt 7 byte of payload into p (payload_array)
		//direct access to skb not allowed
		struct output_t output = {};
		// unsigned long p[32];
		int i = 0;
		int j = 0;
		for (i = payload_offset ; i < (payload_offset + 19) ; i++) {
			output.p[j] = load_byte(skb , i);
			j++;
		}
		output.p[19] = NULL;
		// bpf_trace_printk("%x \r\n", p[0]);
		// bpf_trace_printk("%x \r\n", p[1]);
		// bpf_trace_printk("%x \r\n", p[2]);
		// bpf_trace_printk("%x \r\n", p[3]);
		// bpf_trace_printk("%x \r\n", p[4]);
		// bpf_trace_printk("%x \r\n", p[5]);
		// bpf_trace_printk("%x \r\n", p[6]);
		// for(int x=0; x < 32; x++){
		// 	// bpf_trace_printk("%c \r\n", p[x]);
		// 	// bpf_trace_printk("x");
		// }
		bpf_trace_printk("%x \r\n", output.p);
		
		// int rc;
		// if ((rc = events.perf_submit(ctx, &output, sizeof(output))) < 0)
		// 	bpf_trace_printk("perf_output failed: %d\\n", rc);

		// events.perf_submit(ctx, &output, sizeof(output));
				
		// bpf_trace_printk("\r\n");
		goto DROP;
	}

	// not of interest to us, send it ahead
	SKIP:
	return -1;

	//drop the packet returning 0
	DROP:
	return 0;

}


int dns_matching_dummy(struct __sk_buff *skb)
{
	return -1;
}