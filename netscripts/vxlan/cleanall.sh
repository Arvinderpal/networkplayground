#!/bin/bash
set -x

# /vagrant/netscripts/vxlan/cleanall.sh

OVS_BRIDGE=ovs-br

# clean up
function cleanall () {
	#ovs-ofctl del-flows $OVS_BRIDGE_NAME
	ovs-vsctl del-br $OVS_BRIDGE
	list=`ip netns list`
	for ns in $list   #  <-- Note: Added "" quotes.
	do
		echo Deleting "$ns"  # (i.e. do action / processing of $databaseName here...)
		ip link del "ovs-${ns}-tap"
		ip netns delete "$ns"
	done
}


cleanall