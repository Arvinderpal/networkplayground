#!/usr/bin/python

from __future__ import print_function
from bcc import BPF
from ctypes import *
from sys import argv
from time import sleep

import sys
import socket
import os
import struct

def encode_dns(name):
  size = 32
  if len(name) > 253:
    raise Exception("DNS Name too long.")
  b = bytearray(size)
  i = 0;
  elements = name.split(".")
  for element in elements:
    b[i] = struct.pack("!B", len(element))
    i += 1
    for j in range(0, len(element)):
      b[i] = element[j]
      i += 1


  return (c_ubyte * size).from_buffer(b)


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
    print("examples:")
    print("    http-parse              # bind socket to eth0")
    print("    http-parse -i wlan0     # bind socket to wlan0")
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

# initialize BPF - load source code from http-parse-simple.c
bpf = BPF(src_file = "dns_record.c", debug=0)
# print(bpf.dump_func("dns_test"))

#load eBPF program http_filter of type SOCKET_FILTER into the kernel eBPF vm
#more info about eBPF program types
#http://man7.org/linux/man-pages/man2/bpf.2.html
f_dns = bpf.load_func("dns_record", BPF.SOCKET_FILTER)


#create raw socket, bind it to eth0
#attach bpf program to socket created
BPF.attach_raw_socket(f_dns, interface)

# Create first entry for foo.bar
# key = cache.Key()
# key.p = encode_dns("foo.bar")
# leaf = cache.Leaf()
# leaf.p = (c_ubyte * 4).from_buffer(bytearray(4))
# cache[key] = leaf

# bpf.trace_print()

def print_leaf_value(v):
    for x in xrange(1,32):
        sys.stdout.write( '%s' % chr(v.p[x]) )
    sys.stdout.flush()


incoming = bpf.get_table("incoming")

while True:
    print ("dump: ")
    for k, v in incoming.items():
        print("Key %d : " % k.id)
        print(" -  %d : " % k.src_ip, k.id)
        print_leaf_value(v)
        # print(" Value %s%s%s%s: " % v.p[0], v.p[1], v.p[2], v.p[3])
        print("\n")
    sleep(5)