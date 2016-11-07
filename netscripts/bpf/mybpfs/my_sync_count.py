#!/usr/bin/python
#
# sync_timing.py    Trace time between syncs.
#                   For Linux, uses BCC, eBPF. Embedded C.
#
# Written as a basic example of tracing time between events.
#
# Copyright 2016 Netflix, Inc.
# Licensed under the Apache License, Version 2.0 (the "License")

from __future__ import print_function
from bcc import BPF

# load BPF program
b = BPF(text="""
#include <uapi/linux/ptrace.h>
#include <linux/blkdev.h>

BPF_HASH(last);

void do_trace(struct pt_regs *ctx) {
    u64 ts, *tsp, delta, *oc, nc, key = 0, ckey = 1;

    // attempt to read stored timestamp
    tsp = last.lookup(&key);
    if (tsp != 0) {
        delta = bpf_ktime_get_ns() - *tsp;
        if (delta < 1000000000) {
            // output if time is less than 1 second
            // bpf_trace_printk("%d\\n", delta / 1000000);
        }
        last.delete(&key);
    }

    // update stored timestamp
    ts = bpf_ktime_get_ns();
    last.update(&key, &ts);

    // update count 
    oc = last.lookup(&ckey);
    if (oc != 0){
		nc = (*oc) + 1;
	    last.delete(&ckey); // required due to a bug in kernel: https://git.kernel.org/cgit/linux/kernel/git/davem/net.git/commit/?id=a6ed3ea65d9868fdf9eff84e6fe4f666b8d14b02
	    last.update(&ckey, &nc);
	    bpf_trace_printk("%d\\n", nc);
	} 
	else{
		nc = 1;
	    last.update(&ckey, &nc);
	    bpf_trace_printk("%d\\n", nc);
	}
}
""")

b.attach_kprobe(event="sys_sync", fn_name="do_trace")
print("Tracing for quick sync's... Ctrl-C to end")

# format output
start = 0
while 1:
    (task, pid, cpu, flags, ts, count) = b.trace_fields()
    if start == 0:
        start = ts
    ts = ts - start
    # print("At time %.2f s: multiple syncs detected, last %s ms ago" % (ts, ms))
    print("sync count: %s" % count)
