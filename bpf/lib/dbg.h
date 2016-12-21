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
#ifndef __LIB_DBG__
#define __LIB_DBG__

/* Trace types */
enum {
	DBG_UNSPEC,
	DBG_GENERIC, /* Generic, no message, useful to dump random integers */
	DBG_LOCAL_DELIVERY,
	DBG_ERROR_RET,
	DBG_TO_HOST,
	DBG_TO_STACK,
	DBG_PKT_HASH,
};

/* Capture types */
enum {
	DBG_CAPTURE_UNSPEC,
	DBG_CAPTURE_FROM_NETDEV,
	DBG_CAPTURE_DELIVERY,
};

// TODO(awander): remove this DEBUG:
#define DEBUG

#ifdef DEBUG
#include "events.h"
#include "utils.h"

# define printk(fmt, ...)					\
		({						\
			char ____fmt[] = fmt;			\
			trace_printk(____fmt, sizeof(____fmt),	\
				     ##__VA_ARGS__);		\
		})

#ifndef EVENT_SOURCE
#define EVENT_SOURCE 0
#endif

struct debug_msg {
	NOTIFY_COMMON_HDR
	__u32		arg1;
	__u32		arg2;
	__u32		pad;
};

struct debug_capture_msg {
	NOTIFY_COMMON_HDR
	__u32		len_orig;
	__u32		len_cap;
	__u32		arg1;
};

static inline void regulus_trace(struct __sk_buff *skb, __u8 type, __u32 arg1, __u32 arg2)
{
	uint32_t hash = get_hash_recalc(skb);
	struct debug_msg msg = {
		.type = REGULUS_NOTIFY_DBG_MSG,
		.subtype = type,
		.source = EVENT_SOURCE,
		.hash = hash,
		.arg1 = arg1,
		.arg2 = arg2,
	};

	skb_event_output(skb, &regulus_events, BPF_F_CURRENT_CPU, &msg, sizeof(msg));
}

static inline void regulus_trace_capture(struct __sk_buff *skb, __u8 type, __u32 arg1)
{
	uint64_t skb_len = skb->len, cap_len = min(128ULL, skb_len);
	uint32_t hash = get_hash_recalc(skb);
	struct debug_capture_msg msg = {
		.type = REGULUS_NOTIFY_DBG_CAPTURE,
		.subtype = type,
		.source = EVENT_SOURCE,
		.hash = hash,
		.len_orig = skb_len,
		.len_cap = cap_len,
		.arg1 = arg1,
	};

	skb_event_output(skb, &regulus_events,
			 (cap_len << 32) | BPF_F_CURRENT_CPU,
			 &msg, sizeof(msg));
}

#else
# define printk(fmt, ...)					\
		do { } while (0)

static inline void regulus_trace(struct __sk_buff *skb, __u8 type, __u32 arg1, __u32 arg2)
{
}

static inline void regulus_trace_capture(struct __sk_buff *skb, __u8 type, __u32 arg1)
{
}

#endif

#endif /* __LIB_DBG__ */
