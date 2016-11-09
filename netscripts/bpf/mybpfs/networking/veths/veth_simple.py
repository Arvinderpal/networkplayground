#!/usr/bin/env python

from bcc import BPF
from builtins import input
from pyroute2 import IPRoute, NetNS, IPDB, NSPopen
from random import shuffle
from time import sleep
from simulation import Simulation
import sys

# various linux ip operations
ipr = IPRoute() 
ipdb = IPDB(nl=ipr) 

# load the bpf program
b = BPF(src_file="veth_simple.c", debug=0)
veth_tx_fn = b.load_func("veth_tx", BPF.SCHED_CLS)
veth_rx_fn = b.load_func("veth_rx", BPF.SCHED_CLS)


class VethSimple(object):
	"""docstring for VethSimple"""
	def __init__(self, ipdb):
		super(VethSimple, self).__init__()
		self.ipdb = ipdb
	
	
