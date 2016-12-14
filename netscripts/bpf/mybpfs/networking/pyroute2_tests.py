#!/usr/bin/python

from pyroute2 import netns
from socket import AF_INET
from pyroute2 import IPRoute

# get access to the netlink socket
ip = IPRoute()

# print interfaces
# print(ip.get_links())

# NOTE: do this in case veth or netns exist:
# ip link del v0p0;  ip netns del test

netns.create('test')

# create VETH pair and move v0p1 to netns 'test'
ip.link_create(ifname='v0p0', peer='v0p1', kind='veth')
idx = ip.link_lookup(ifname='v0p1')[0]
ip.link('set',
        index=idx,
        net_ns_fd='test')

# bring v0p0 up and add an address
idx = ip.link_lookup(ifname='v0p0')[0]
ip.link('set',
        index=idx,
        state='up')
ip.addr('add',
        index=idx,
        address='10.0.0.1',
        broadcast='10.0.0.255',
        prefixlen=24)


# create a route with metrics
ip.route('add',
         dst='172.16.0.0/24',
         gateway='10.0.0.10',
         metrics={'mtu': 1400,
                  'hoplimit': 16})


# release Netlink socket
ip.close()