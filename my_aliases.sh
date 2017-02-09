###########
# OVS cmd #
###########

sudo su

# OVS_BRIDGE_NAME=ovs-br
OVS_BRIDGE_NAME=ovsv1-br-cntm

alias oof='sudo ovs-ofctl'
alias ovs='sudo ovs-vsctl'
alias oapp='sudo ovs-appctl'
alias odp='sudo ovs-dpctl'

# Show
alias oshow="sudo ovs-vsctl show"
alias oofshow="sudo ovs-ofctl show $OVS_BRIDGE_NAME"
alias odpshow='sudo ovs-dpctl show'

# Logs
alias ologs="sudo tail -n 300 /var/log/openvswitch/ovs-vswitchd.log"

# DUMP flow/table 
alias ofdbshow="sudo ovs-appctl fdb/show $OVS_BRIDGE_NAME"
alias oappdump="sudo ovs-appctl bridge/dump-flows $OVS_BRIDGE_NAME"
alias odpdump=" sudo ovs-dpctl dump-flows "
alias oofdump="sudo ovs-ofctl dump-flows $OVS_BRIDGE_NAME"
alias odumpports=" sudo ovs-ofctl -O OpenFlow13 dump-ports $OVS_BRIDGE_NAME"

alias oclean="sudo ovs-ofctl del-flows $OVS_BRIDGE_NAME ; ovs-vsctl del-br $OVS_BRIDGE_NAME"

# Datapath - Conntrack Dump
alias oconndump="sudo ovs-appctl dpctl/dump-conntrack"

# tracing
alias otrace="oapp ofproto/trace"

# Misc 
alias ifve="sudo ifconfig | grep ve-"
alias ns="ip netns exec"

alias ns1="ip netns exec ns1 bash"
alias ns2="ip netns exec ns2 bash"

cd /usr/share/bcc

###########
# Regulus #
###########
./regulus daemon run -debug -D /root/go/src/github.com/networkplayground/bpf --d eth1 --n 192.168.80.201 
./regulus daemon g3map list
./regulus daemon g3map update 10.0.2.66=200
./regulus daemon g3map delete 10.0.2.66
./regulus monitor
###########
# Vagrant #
###########

v up --provision-with setupkernel --provider virtualbox; v reload --provision-with bootstrap,setupbcc,setupxdp,regulus
v destroy -f
v up --provision-with setupkernel --provider virtualbox; v reload --provision-with bootstrap,setupbcc,setupxdp; v reload --provision-with networksetup,simplenetwork

/vagrant/netscripts/vxlan/quickprovision.sh $HOSTNAME


###############
#    CNI      #
###############
cd ~/go/src/github.com/networkplayground/plugins/regulus-k8/cni 
make clean ; make; make install
cd scripts/ 
CNI_PATH=$CNI_PATH ./docker-run.sh --rm busybox:latest ifconfig


###############
# Docker      #
###############
docker run -it ubuntu date
docker run -it ubuntu /bin/bash
# plugins 
docker network create --driver regulus mybr1
docker network connect mybr1 hungry_murdock

docker run --network=mynet busybox top

###############
# Linux Build #
###############

make clean
mkdir -p /home/vagrant/linux/build/linux-4.9-rc5
make O=/home/vagrant/linux/build/linux-4.9-rc5 olddefconfig
make O=/home/vagrant/linux/build/linux-4.9-rc5
make O=/home/vagrant/linux/build/linux-4.9-rc5 modules_install install

###########
# tcpdump #
###########

tcpdump -ni ovs-br -s0 -w /vagrant/etcd-01-ext0.pcap
tcpdump -ni eth1 -s0 -w /vagrant/etcd-01-eth1.pcap
tcpdump -ni eth0 -s0 -w /vagrant/etcd-01-eth0.pcap

###########
# iperf #
###########

# tcp
iperf -c 192.168.80.203 -p 12000
iperf -s  -p 12000
# udp
iperf -s -u
iperf -u -c 172.16.60.151

conntrack -E -p tcp

# UDP echo
# server:
socat -v PIPE udp-recvfrom:4222,fork 
# client:
socat - udp:localhost:4222

# TCP echo
socat -v tcp-l:4222,fork exec:'/bin/cat'
# client:
nc serverip 4222