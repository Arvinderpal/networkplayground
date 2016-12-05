#!/usr/bin/python

# sudo ./my_helloworld.py"
from bcc import BPF

# initialize BPF 
bpf = BPF(src_file = "my_helloworld.c", debug=0)

bpf.attach_kprobe(event="sys_sync", fn_name="hello")

print("Tracing sys_sync()... Ctrl-C to end.")
bpf.trace_print()
