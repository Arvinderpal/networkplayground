#!/usr/bin/python

from __future__ import print_function
from bcc import BPF
from ctypes import *
from sys import argv
from time import sleep
from netaddr import IPAddress

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
# load bpf -- it's a socket filter
f_dns = bpf.load_func("dns_record", BPF.SOCKET_FILTER)
# create a raw socket on eth0 and attach our bpf
BPF.attach_raw_socket(f_dns, interface)


# bytecode_str = bpf.dump_func("dns_record")
# print(":".join("{:02x}".format(ord(c)) for c in bytecode_str))

# # dump the BPF program
# bpf.dump_func("dns_record")



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
        out = "Key: " + str(k.id) + "IP: " + str(IPAddress(k.src_ip)) + " Query: "
        # print("Key %d IP: %s: " % k.id, str(IPAddress(k.src_ip)) )
        sys.stdout.write( '%s' % out )
        print_leaf_value(v)
        # print(" Value %s%s%s%s: " % v.p[0], v.p[1], v.p[2], v.p[3])
        print("\n")
    print("\n----------------------\n")
    sleep(5)