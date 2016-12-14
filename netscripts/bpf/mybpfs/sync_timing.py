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
import ctypes as ct

# load BPF program
b = BPF(text="""
#include <uapi/linux/ptrace.h>
#include <linux/blkdev.h>
#include <linux/sched.h>

// define output data struct in C
struct data_t {
	u64 delta; 
};

BPF_PERF_OUTPUT(events);
BPF_HASH(last);

void do_trace(struct pt_regs *ctx) {
    u64 ts, *tsp, delta, key = 0;

    // attempt to read stored timestamp
    tsp = last.lookup(&key);
    if (tsp != 0) {
        struct data_t data = {};
	    data.delta = bpf_ktime_get_ns() - *tsp;
        if (data.delta < 1000000000) {
            // output if time is less than 1 second
            // bpf_trace_printk("%d\\n", delta / 1000000);
		    events.perf_submit(ctx, &data, sizeof(data));

        }
        last.delete(&key);
    }

    // update stored timestamp
    ts = bpf_ktime_get_ns();
    last.update(&key, &ts);
}
""")

b.attach_kprobe(event="sys_sync", fn_name="do_trace")
print("Tracing for quick sync's... Ctrl-C to end")

# define output data structure in Python
class Data(ct.Structure):
    _fields_ = [("delta", ct.c_ulonglong)]


# process event
start = 0
def print_event(cpu, data, size):
    event = ct.cast(data, ct.POINTER(Data)).contents
    time_s = float(event.delta) / 1000000000
    print("%-18.9f %s" % (time_s, "ms ago last sync detected "))

# loop with callback to print_event
b["events"].open_perf_buffer(print_event)
while 1:
    b.kprobe_poll()

