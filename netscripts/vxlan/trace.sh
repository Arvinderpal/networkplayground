#!/bin/bash

# /vagrant/netscripts/vxlan/trace.sh etcd-01

HOST=$1

tcpdump -ni eth0 -s0 -w /vagrant/"${HOST}"eth0..pcap &
tcpdump -ni eth1 -s0 -w /vagrant/"${HOST}"eth1.pcap &

tcpdump -ni ovs-br -s0 -w /vagrant/"${HOST}"ovs-br.pcap &
tcpdump -ni csg0 -s0 -w /vagrant/"${HOST}"csg0.pcap &

tcpdump -ni ovs-ns1-tap -s0 -w /vagrant/"${HOST}"ovs-ns1-tap.pcap &
tcpdump -ni ovs-ns2-tap -s0 -w /vagrant/"${HOST}"ovs-ns2-tap.pcap &

# wait for user
read input

killall tcpdump
