
#ifndef __LIB_COMMON_H_
#define __LIB_COMMON_H_

// #include <bpf_features.h>
#include <bpf/api.h>
#include <linux/if_ether.h>
#include <linux/ip.h>
#include <linux/in.h>
#include <stdint.h>

typedef __u64 mac_t;

enum {
	REGULUS_NOTIFY_UNSPEC,
	REGULUS_NOTIFY_DROP,
	REGULUS_NOTIFY_DBG_MSG,
	REGULUS_NOTIFY_DBG_CAPTURE,
};

#define NOTIFY_COMMON_HDR \
	__u8		type; \
	__u8		subtype; \
	__u16		source; \
	__u32		hash;


#define IS_ERR(x) (unlikely((x < 0) || (x == TC_ACT_SHOT)))

/* Regulus error codes, must NOT overlap with TC return codes */
#define DROP_INVALID_SMAC	-130
#define DROP_INVALID_DMAC	-131
#define DROP_INVALID_SIP	-132
#define DROP_MISC			-133
#define DROP_INVALID		-134
#define DROP_UNKNOWN_L3		-135
#define DROP_MISSED_TAIL_CALL	-136
#define DROP_WRITE_ERROR	-137
#define DROP_UNKNOWN_L4		-138
#define DROP_CSUM_L3		-153
#define DROP_CSUM_L4		-154

struct g3map_key {
	__be32 address;
} __attribute__((packed));

struct g3map_value {
	__u16 count;
} __attribute__((packed));


#endif