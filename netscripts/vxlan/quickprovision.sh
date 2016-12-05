#!/bin/bash
set -ex

HOST=$1
EXTERNAL_IF="eth0"

REMOTE1_IP="192.168.80.201"
REMOTE2_IP="192.168.80.202"
# REMOTE3_IP="192.168.80.203"

case "$HOST" in	
	etcd-01)
		/vagrant/netscripts/vxlan/setup.sh 10.1.0.0/16 10.1.1.0/24 10.1.2.0/24 10.1.3.0/24 $REMOTE2_IP $REMOTE3_IP $EXTERNAL_IF
		/vagrant/netscripts/vxlan/simplenetwork.sh etcd-01 10.1.1. 10.1.1.0/24 $EXTERNAL_IF
		/vagrant/netscripts/vxlan/trace.sh etcd-01
		;;
	etcd-02)
		/vagrant/netscripts/vxlan/setup.sh 10.1.0.0/16 10.1.2.0/24 10.1.1.0/24 10.1.3.0/24 $REMOTE1_IP $REMOTE3_IP $EXTERNAL_IF
		/vagrant/netscripts/vxlan/simplenetwork.sh etcd-02 10.1.2. 10.1.2.0/24 $EXTERNAL_IF
		/vagrant/netscripts/vxlan/trace.sh etcd-02
		;;
	# etcd-03)
	# 	/vagrant/netscripts/vxlan/setup.sh 10.1.0.0/16 10.1.3.0/24 10.1.1.0/24 10.1.2.0/24 $REMOTE1_IP $REMOTE2_IP $EXTERNAL_IF
	# 	/vagrant/netscripts/vxlan/simplenetwork.sh etcd-03 10.1.3. 10.1.3.0/24 $EXTERNAL_IF
	# 	/vagrant/netscripts/vxlan/trace.sh etcd-03
	# 	;;
	*)
		echo "Invalid HOST: $@"
		exit 1
	esac

