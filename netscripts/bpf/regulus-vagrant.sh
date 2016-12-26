#!/bin/bash

function regulus_setup(){
	# RegulusPath   = "/var/run/regulus"
	mkdir -p /var/run/regulus
	# DefaultLibDir = "/usr/lib/regulus"
	mkdir -p /usr/lib/regulus
	# BPFMapRoot     = "/sys/fs/bpf"
	mkdir -p /sys/fs/bpf	
	# BPFRegulusMaps = BPFMapRoot + "/tc/globals"
	# BPFMap         = BPFRegulusMaps + "/regulus_lxc"

	groupadd -f regulus
	usermod -a -G regulus vagrant


	# VAGRANT_MOUNT_DIR=/vagrant/
	# VAGRANT_MOUNT_DIR=/root/go/src/github.com/networkplayground

	echo 'REGULUS_HOME="/root/go/src/github.com/networkplayground"' >> /root/.bashrc
	echo 'PATH=$PATH:"${REGULUS_HOME}/"' >> /root/.bashrc
	# bpf/ contains scripts like init.sh
	# ideally we should move this scripts to dir like /usr/local/bin
	echo 'PATH=$PATH:"${REGULUS_HOME}/bpf"' >> /root/.bashrc

	echo 'export GOPATH=/root/go' >> ~/.bashrc
	echo 'export PATH=$PATH:.:$GOPATH/bin' >> ~/.bashrc
	
	echo 'cd $REGULUS_HOME' >> /root/.bashrc

}

regulus_setup
