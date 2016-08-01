#!/bin/bash
set -ex

HOST=$1
EXTERNAL_IF="eth0"

case "$HOST" in
	etcd-01)
		/vagrant/netscripts/vxlan/setup.sh 10.1.0.0/16 10.1.1.0/24 10.1.2.0/24 10.1.3.0/24 192.168.70.202 192.168.70.203 $EXTERNAL_IF
		/vagrant/netscripts/vxlan/simplenetwork.sh etcd-01 10.1.1. 10.1.1.0/24 $EXTERNAL_IF
		/vagrant/netscripts/vxlan/trace.sh etcd-01
		;;
	etcd-02)
		/vagrant/netscripts/vxlan/setup.sh 10.1.0.0/16 10.1.2.0/24 10.1.1.0/24 10.1.3.0/24 192.168.70.201 192.168.70.203 $EXTERNAL_IF
		/vagrant/netscripts/vxlan/simplenetwork.sh etcd-02 10.1.2. 10.1.2.0/24 $EXTERNAL_IF
		/vagrant/netscripts/vxlan/trace.sh etcd-02
		;;
	etcd-03)
		/vagrant/netscripts/vxlan/setup.sh 10.1.0.0/16 10.1.3.0/24 10.1.1.0/24 10.1.2.0/24 192.168.70.201 192.168.70.202 $EXTERNAL_IF
		/vagrant/netscripts/vxlan/simplenetwork.sh etcd-03 10.1.3. 10.1.3.0/24 $EXTERNAL_IF
		/vagrant/netscripts/vxlan/trace.sh etcd-03
		;;
	*)
		echo "Invalid HOST: $@"
		exit 1
	esac

