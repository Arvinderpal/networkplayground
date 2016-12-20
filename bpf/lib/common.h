
#ifndef __LIB_COMMON_H_
#define __LIB_COMMON_H_

// #include <bpf_features.h>
#include <bpf/api.h>
#include <linux/if_ether.h>
#include <linux/ip.h>
#include <linux/in.h>
#include <stdint.h>

typedef __u64 mac_t;

/* Regulus error codes, must NOT overlap with TC return codes */
#define DROP_INVALID_SMAC	-130
#define DROP_INVALID_DMAC	-131
#define DROP_INVALID_SIP	-132
#define DROP_MISC			-133
#define DROP_INVALID		-134

struct g3map_key {
	__be32 address;
} __attribute__((packed));

struct g3map_value {
	__u16 count;
} __attribute__((packed));


#endif