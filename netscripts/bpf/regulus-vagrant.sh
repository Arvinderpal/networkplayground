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

	echo 'cd /vagrant' >> /home/vagrant/.bashrc

}


regulus_setup