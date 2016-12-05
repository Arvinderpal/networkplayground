#!/usr/bin/env python

from __future__ import print_function
from bcc import BPF
from builtins import input
from pyroute2 import IPRoute, NetNS, IPDB, NSPopen
from random import shuffle
from ctypes import *
from sys import argv
from time import sleep
from netaddr import IPAddress

import sys
import socket
import os
import struct


#args
def usage():
    print("USAGE: %s [-i <if_name>]" % argv[0])
    print("")
    print("Try '%s -h' for more options." % argv[0])
    exit()

#help
def help():
    print("USAGE: %s [-i <if_name>]" % argv[0])
    print("")
    print("optional arguments:")
    print("   -h                       print this help")
    print("   -i if_name               select interface if_name. Default is eth0")
    print("")
    exit()

#arguments
interface="eth0"

if len(argv) == 2:
  if str(argv[1]) == '-h':
    help()
  else:
    usage()

if len(argv) == 3:
  if str(argv[1]) == '-i':
    interface = argv[2]
  else:
    usage()

if len(argv) > 3:
  usage()


# various linux ip operations
ipr = IPRoute() 
ipdb = IPDB(nl=ipr) 

# load the bpf program
bpf = BPF(src_file="traffic_counter.c", debug=0)
veth_tx_fn = bpf.load_func("veth_tx", BPF.SCHED_CLS)
veth_rx_fn = bpf.load_func("veth_rx", BPF.SCHED_CLS)

state = bpf.get_table("state")

ifc = ipdb.interfaces.eth1

ipr.tc("add", "ingress", ifc.index, "ffff:")
ipr.tc("add-filter", "bpf", ifc.index, ":1", fd=veth_rx_fn.fd,
       name=veth_rx_fn.name, parent="ffff:", action="ok", classid=1)
ipr.tc("add", "sfq", ifc.index, "1:")
ipr.tc("add-filter", "bpf", ifc.index, ":1", fd=veth_tx_fn.fd,
       name=veth_tx_fn.name, parent="1:", action="ok", classid=1)

state = bpf.get_table("state")

while True:
    print ("dump: ")
    for k, v in state.items():
        out = "Count: " + "tx(%s, %s B), rx(%s, %s B)" % (v.tx_pkts, v.tx_bytes, v.rx_pkts, v.rx_bytes)
        # print("Key %d IP: %s: " % k.id, str(IPAddress(k.src_ip)) )
        sys.stdout.write( '%s' % out )
        sys.stdout.flush()
        print("\n")
    print("\n----------------------\n")
    sleep(5)


ipdb.release()
