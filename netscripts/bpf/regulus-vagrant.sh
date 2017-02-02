#!/bin/bash

USER_HOME="/root"
USER_GOPATH="${USER_HOME}/go"
K8_HOME="${USER_GOPATH}/src/k8s.io/kubernetes"
REGULUS_HOME="${USER_GOPATH}/src/github.com/networkplayground"
REGULUS_PATHS="."

function install_k8(){

	cd $USER_HOME
	# K 1.5 requires etcd >= 3.0.14 
	curl -L  https://github.com/coreos/etcd/releases/download/v3.0.14/etcd-v3.0.14-linux-amd64.tar.gz -o etcd-v3.0.14-linux-amd64.tar.gz
	tar xzvf etcd-v3.0.14-linux-amd64.tar.gz

	REGULUS_PATHS="${REGULUS_PATHS}:${USER_HOME}/etcd-v3.0.14-linux-amd64"
		
	mkdir -p "${USER_GOPATH}/src/k8s.io"
	cd "${USER_GOPATH}/src/k8s.io"
	git clone -b v1.5.0 https://github.com/kubernetes/kubernetes.git
	# sudo chown -R vagrant.vagrant kubernetes
	cd kubernetes
	# patch -p1 < /home/vagrant/go/src/github.com/cilium/cilium/examples/kubernetes/kubernetes-v1.4.0.patch
}

function regulus_env_setup(){
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

	echo "export REGULUS_HOME=${REGULUS_HOME}" >> "${USER_HOME}/.bashrc"
	# bpf/ contains regulus scripts like init.sh
	REGULUS_PATHS="${REGULUS_PATHS}:${REGULUS_HOME}:${REGULUS_HOME}/bpf"
	
	echo "export GOPATH=${USER_GOPATH}" >> "${USER_HOME}/.bashrc"
	REGULUS_PATHS="${REGULUS_PATHS}:${USER_GOPATH}/bin"
	
	# K8_HOME is by kube-env.sh and other scripts. 
	echo "export K8_HOME=${K8_HOME}" >> "${USER_HOME}/.bashrc"

	# my-env-setup.sh contains some useful scripts
	echo "source ${REGULUS_HOME}/plugins/regulus-k8/scripts/my-env-setup.sh" >> "${USER_HOME}/.bashrc"

	echo "cd ${REGULUS_HOME}" >> "${USER_HOME}/.bashrc"

}

function regulus_add_cni(){

	# build and install host-local ipam 
	# assumes cni directory under root/go/src/github.com/containernetworking/cni
	cd "${USER_GOPATH}/src/github.com/containernetworking/cni"
	./build
	mkdir -p /opt/cni/bin
	cp bin/host-local loopback /opt/cni/bin

	# build and install regulus cni binaries
	cd "${REGULUS_HOME}/plugins/regulus-k8/cni"
	make clean
	make 
	# install will also put 10-regulus-cni.conf in /etc/cni/net.d
	make install

}

regulus_env_setup
install_k8
regulus_add_cni

echo "export PATH=$PATH:${REGULUS_PATHS}" >> "${USER_HOME}/.bashrc"

# add_aliases
# See: regulus-k8/scripts/my-env-setup.sh
# function add_aliases(){
# cat <<EOT >> "${USER_HOME}/.bashrc"
# alias cdnet="cd ${REGULUS_HOME}"
# alias cdk8="cd ${K8_HOME}"
# EOT
# }
