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

/* FIXME: Make configurable */
// should be in sync with const.go
#define REGULUS_G3MAP_MAX_ENTRIES	65535

__BPF_MAP(regulus_g3, BPF_MAP_TYPE_HASH, 0,
	  sizeof(struct g3map_key), sizeof(struct g3map_value),
	  PIN_GLOBAL_NS, REGULUS_G3MAP_MAX_ENTRIES);




static inline struct g3map_value *g3_lookup_value(struct __sk_buff *skb,
						     struct g3map_key *key)
{
	struct g3map_value *value;

	/* FIXME: The verifier barks on these calls right now for some reason */
	/* cilium_trace(skb, DBG_LB4_LOOKUP_MASTER, key->address, key->dport); */
	value = map_lookup_elem(&regulus_g3, key);
	if (value){
		return value;
	}

	// cilium_trace(skb, DBG_LB4_LOOKUP_MASTER_FAIL, 0, 0);
	return NULL;
}

#endif /* __G3_H_ */