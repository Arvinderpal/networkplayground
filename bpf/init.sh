#!/bin/bash
# ./init.sh . /var/run/regulus direct eth1
# ./init.sh /root/go/src/github.com/networkplayground/bpf /var/run/regulus direct eth1
# ./regulus daemon run -D /root/go/src/github.com/networkplayground/bpf --d eth1

LIB=$1
RUNDIR=$2
# ADDR=$3
# V4ADDR=$4
MODE=$3
# Only set if MODE = "direct" or "lb"
NATIVE_DEV=$4

DEBUG

MOUNTPOINT="/sys/fs/bpf"

set -e
set -x

# Enable JIT
echo 1 > /proc/sys/net/core/bpf_jit_enable

# check to see $MOUNTPOINT is mounted, if not, mount it
if [ $(mount | grep $MOUNTPOINT > /dev/null) ]; then
	mount bpffs $MOUNTPOINT -t bpf
fi

function mac2array()
{
	echo "{0x${1//:/,0x}}"
}


function bpf_compile()
{
	DEV=$1
	OPTS=$2
	IN=$3
	OUT=$4

	NODE_MAC=$(ip link show $DEV | grep ether | awk '{print $2}')
	NODE_MAC="{.addr=$(mac2array $NODE_MAC)}"

	clang $CLANG_OPTS $OPTS -DNODE_MAC=${NODE_MAC} -c $LIB/$IN -o $OUT

	tc qdisc del dev $DEV clsact 2> /dev/null || true
	tc qdisc add dev $DEV clsact
	
	tc filter add dev $DEV ingress bpf da obj $OUT sec $5
	# e.g. tc filter add dev eth1 ingress bpf da obj bpf_g3.o sec from-netdev
}

# This directory was created by the daemon and contains the per container header file
DIR="$PWD/globals"
if [ -z "$DEBUG" ]; then
	CLANG_OPTS="-D__NR_CPUS__=$(nproc) -O2 -target bpf -I$DIR -I. -I$LIB/include -DHANDLE_NS -DDEBUG"
else
	CLANG_OPTS="-D__NR_CPUS__=$(nproc) -O2 -target bpf -I$DIR -I. -I$LIB/include -DHANDLE_NS"
fi



# TODO(awander): what is run_probes.sh? do we need it?
# $LIB/run_probes.sh $LIB $RUNDIR

# NOTE(awander): I wonder if we will need this?
# I'm guess not if we are doing "direct" since same bpf (netdev.c) is attached below
# They create a veth pair (HOST_DEV1 and HOST_DEV2) and assign the NodeAddress 
# to them. The BPF below is compiled at attached to HOST_DEV2
# Also, it may be that they are using a "special" netns to do all their processing??
# bpf_compile $HOST_DEV2 "$OPTS" bpf_netdev.c bpf_netdev_ns.o from-netdev


if [ "$MODE" = "direct" ]; then
	if [ -z "$NATIVE_DEV" ]; then
		echo "No device specified for direct mode, ignoring..."
	else

		# TODO(awander): do we need to enable ipv4 forwarding? see setup.sh..
		# sysctl -w net.ipv6.conf.all.forwarding=1

		# NOTE(awander): note the cleaver way to pass defines to the compiler!
		# ID=$(cilium policy get-id $WORLD_ID 2> /dev/null)
		# OPTS="-DSECLABEL=${ID} -DPOLICY_MAP=cilium_policy_reserved_${ID}"
		bpf_compile $NATIVE_DEV "$OPTS" bpf_g3.c bpf_g3.o from-netdev

		echo "$NATIVE_DEV" > $RUNDIR/device.state
	fi
else
	FILE=$RUNDIR/device.state
	if [ -f $FILE ]; then
		DEV=$(cat $FILE)
		echo "Removed BPF program from device $DEV"
		tc qdisc del dev $DEV clsact 2> /dev/null || true
		rm $FILE
	fi
fi
