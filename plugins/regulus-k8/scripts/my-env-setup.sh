#!/usr/bin/env bash

source "$REGULUS_HOME/plugins/regulus-k8/scripts/env-kube.sh"

if [ -z "$K8_HOME" ]; then
    echo "K8_HOME is not defined, using default: /root/go/src/k8s.io/kubernetes"
    export kubectl="/root/go/src/k8s.io/kubernetes/cluster/kubectl.sh -s $API_HOST:$API_PORT"
else
    export kubectl="$K8_HOME/cluster/kubectl.sh -s $API_HOST:$API_PORT"
fi

alias k8c="$kubectl"
alias cdk8="cd $K8_HOME"
alias cdscripts="cd $REGULUS_HOME/plugins/regulus-k8/scripts"

# export PATH=$PATH:"${K8_HOME}/cluster"

# local k8:
function k8localrun(){
	export NET_PLUGIN=cni
	export NET_PLUGIN_DIR=/etc/cni/net.d
	cdk8
	hack/local-up-cluster.sh
}

# function k8localrun_apceranet(){
# 	# clean up ovs state
# 	#sudo ovs-ofctl del-flows ovs-test 
# 	#sudo ovs-vsctl del-br ovs-br
# 	# copy latest setup scripts callsed apceranet plugin in kubelet
# 	sudo mkdir -p /opt/apceranet
# 	sudo cp $K8_HOME/pkg/kubelet/network/apceranet/drivers/ovsv1/scripts/* /opt/apceranet
# #	sudo chmod 744 /opt/apceranet/setup_bridge.sh
# #	sudo chmod 744 /opt/apceranet/setup_tunnel.sh
# #	sudo chmod 744 /opt/apceranet/allow_ingress.sh
# #	sudo chmod 744 /opt/apceranet/allow_ingress_same_host.sh
# #	sudo chmod 744 /opt/apceranet/isolation_on_off.sh

# 	sudo rm -rf /opt/apceranet/gen-rules
# 	sudo mkdir -p /opt/apceranet/gen-rules/

# 	# copy latest ovsv1 plugin binary
# 	sudo cp $KURMANET_HOME/plugins/main/ovsv1/ovsv1 /opt/cni/bin
# 	sudo cp $KURMANET_HOME/plugins/main/ovsv1/ovsv1.sh /opt/cni/bin
# 	sudo chmod 744 /opt/cni/bin/ovsv1.sh
# 	sudo rm /tmp/ovsv1.log.s
# 	# clean up host-subnet ipam plugin directory
# 	sudo rm -rf /var/lib/cni/networks/apceranet/
# 	export NET_PLUGIN=apceranet
# 	export NET_PLUGIN_DIR=/etc/cni/net.d
# 	# sudo cp /mnt/hgfs/gopath/src/github.com/apcera/kurma-netplugin/scripts/10-apceranet.conf $NET_PLUGIN_DIR
# 	cdk8
# #	export HOSTNAME_OVERRIDE="main-node"
# 	hack/local-up-cluster.sh
# }

function k8localrun_default(){
	unset NET_PLUGIN
	unset NET_PLUGIN_DIR
	cdk8
	hack/local-up-cluster.sh
}

# function k8e2e_setup_env(){
# export PATH=$PATH:/home/apcerian/go/bin  	
# export KUBECONFIG=/home/apcerian/.kube/config
# export KUBE_MASTER_IP=127.0.0.1:8080
# export KUBE_MASTER=127.0.0.1
# export KUBECTL_PATH=$K8_HOME/cluster/kubectl.sh
# #export KUBE_ROOT=$K8_HOME
# export KUBERNETES_PROVIDER=local
# export KUBERNETES_SRC_PATH=$K8_HOME
# }

alias k8describe="k8c describe"
alias k8create="k8c create -f"
alias k8exec="k8c exec -i "

# Pods
alias k8podsget="k8c get pods -o wide"
alias k8podsgetall="k8c get pods -o wide --all-namespaces"
alias k8podsdel="k8c delete pods"
alias k8podattach="k8c attach $@ -t -i"

REGULUS_EXAMPLES_DIR="$REGULUS_HOME/plugins/regulus-k8/scripts/examples"

# Using this approach creates problems weird behavior during delete:
#function k8createbusybox () {
#	k8c run -i --tty "$@" --image=busybox --restart=Never -- sh --tty 
#}
alias k8create_bb1="k8create ${REGULUS_EXAMPLES_DIR}/mypods/bb1.yml"
alias k8create_bb2="k8create ${REGULUS_EXAMPLES_DIR}/mypods/bb2.yml"
alias k8create_nginx="k8create ${K8_HOME}/docs/user-guide/pod.yaml"
alias k8create_nginxreplicas="k8create run my-nginx --image=nginx --replicas=2 --port=80"
alias k8create_redis_django="k8create ${REGULUS_EXAMPLES_DIR}/mypods/redis_and_django.yml"

# Namespaces
alias k8nsget="k8c get namespaces"
alias k8nscreate_a_namespace="k8create ${REGULUS_EXAMPLES_DIR}/namespaces/create_a_namespace.yml"
alias k8nscreate_b_namespace="k8create ${REGULUS_EXAMPLES_DIR}/namespaces/create_b_namespace.yml"
alias k8nscreate_c_namespace="k8create ${REGULUS_EXAMPLES_DIR}/namespaces/create_c_namespace.yml"
alias k8nscreate_d_namespace="k8create ${REGULUS_EXAMPLES_DIR}/namespaces/create_d_namespace.yml"
alias k8nscurrent="k8c config view | grep namespace:"
function k8nsswitch(){
	CONTEXT=$(k8c config view | grep current-context | awk '{print $2}')
	echo "Using this context: "$CONTEXT
	k8c config set-context $CONTEXT --namespace=$@
}

# TPR
alias k8tprlist="curl http://$API_HOST:$API_PORT/apis/extensions/v1beta1/thirdpartyresources"
alias k8tprcreate-networkpolicy="k8c create -f /home/apcerian/misc/thirdpartyresources/network-policy-tpr"
alias k8tprcreatesql="k8c create -f /home/apcerian/misc/thirdpartyresources/mysql-resource"
alias k8tprcreatecrontab="k8c create -f /home/apcerian/misc/thirdpartyresources/cront-tab-resource"
alias k8tprcrontab_instancelist="curl http://$API_HOST:$API_PORT/apis/stable.example.com/v1/namespaces/default/crontabs"
alias k8tprcrontab_instancecreate="curl -H \"Content-Type: application/json\" --data @/home/apcerian/misc/thirdpartyresources/cront-tab-instance.json http://$API_HOST:$API_PORT/apis/stable.example.com/v1/namespaces/default/crontabs"
#curl -H "Content-Type: application/json" -X POST -d '{"metadata":{"name":"my-second-cron-object"},"apiVersion":"stable.example.com/v1","kind":"CronTab","cronSpec":"blah 2 2 ","image":"myimage2 2 2"}' http://$API_HOST:$API_PORT/apis/stable.example.com/v1/namespaces/default/crontabs


alias k8npshow="curl http://$API_HOST:$API_PORT/apis/extensions/v1beta1/networkpolicies"
# Namespace selector
function k8npcreate_ns_frontbackend(){
	k8create ${REGULUS_EXAMPLES_DIR}/namespaces/create_front_ns.yml
	k8create ${REGULUS_EXAMPLES_DIR}/namespaces/create_back_ns.yml
	k8c annotate ns front-ns "net.beta.kubernetes.io/network-policy={\"ingress\":{\"isolation\":\"DefaultDeny\"}}"
	k8c annotate ns back-ns "net.beta.kubernetes.io/network-policy={\"ingress\":{\"isolation\":\"DefaultDeny\"}}"

	k8c create -f ${REGULUS_EXAMPLES_DIR}/networkpolicy/allow-ingress-from-front-ns.yml 

	k8c --namespace=front-ns create -f ${REGULUS_EXAMPLES_DIR}/networkpolicy/bb_front1.yml
	k8c --namespace=back-ns create -f ${REGULUS_EXAMPLES_DIR}/networkpolicy/bb_back1.yml	
}


function k8npcreate_pod_frontbackend_tcp(){
	k8nscreate_b_namespace
	k8c annotate ns b-namespace "net.beta.kubernetes.io/network-policy={\"ingress\":{\"isolation\":\"DefaultDeny\"}}"

	k8c --namespace=b-namespace create -f ${REGULUS_EXAMPLES_DIR}/networkpolicy/bb_front1.yml
	k8c --namespace=b-namespace create -f ${REGULUS_EXAMPLES_DIR}/networkpolicy/bb_back1.yml
#	k8createbusybox front1
#	k8c label pods front1 role=frontend

	k8c --namespace=b-namespace create -f ${REGULUS_EXAMPLES_DIR}/networkpolicy/backend-policy.yaml

	k8nsswitch b-namespace
	k8nscurrent 

}

# Delete policy: k8c delete -f ${REGULUS_EXAMPLES_DIR}/networkpolicy/backend-policy-udp.yaml
# USAGE: 
# k8c exec -i alp-back2 -- nc -lk -u -p 11000
# k8c exec -i alp-front2 -- nc -u 192.168.0.3:11000
alias k8pod_back2_udp="k8exec alp-back2 -- nc -lk -u -p 11000"
alias k8pod_front2_udp="k8exec alp-front2 -- nc -u " #192.168.0.3:11000
function k8npcreate_pod_frontbackend_udp(){
	k8nscreate_a_namespace
	k8c annotate ns a-namespace "net.beta.kubernetes.io/network-policy={\"ingress\":{\"isolation\":\"DefaultDeny\"}}"
	k8c --namespace=a-namespace create -f ${REGULUS_EXAMPLES_DIR}/networkpolicy/alpine-front2.yml
	k8c --namespace=a-namespace create -f ${REGULUS_EXAMPLES_DIR}/networkpolicy/alpine-back2.yml
	k8c --namespace=a-namespace create -f ${REGULUS_EXAMPLES_DIR}/networkpolicy/backend-policy-udp.yaml
	k8nsswitch a-namespace
	k8nscurrent 
}

# A namespace where all pods can talk to all other pods in the same namespace
function k8npcreate_open(){
	k8nscreate_c_namespace
	k8c annotate ns c-namespace "net.beta.kubernetes.io/network-policy={\"ingress\":{\"isolation\":\"DefaultDeny\"}}"
	k8c --namespace=c-namespace create -f ${REGULUS_EXAMPLES_DIR}/networkpolicy/alpine-front2.yml
	k8c --namespace=c-namespace create -f ${REGULUS_EXAMPLES_DIR}/networkpolicy/alpine-back2.yml
	k8c --namespace=c-namespace create -f ${REGULUS_EXAMPLES_DIR}/networkpolicy/allow-all.yml
	k8nsswitch c-namespace
	k8nscurrent 
}

# Open TCP 80 and UDP 50 
function k8npcreate_many_ports(){
	k8nscreate_d_namespace
	k8c annotate ns d-namespace "net.beta.kubernetes.io/network-policy={\"ingress\":{\"isolation\":\"DefaultDeny\"}}"
	k8c --namespace=d-namespace create -f ${REGULUS_EXAMPLES_DIR}/networkpolicy/alpine-front2.yml
	k8c --namespace=d-namespace create -f ${REGULUS_EXAMPLES_DIR}/networkpolicy/alpine-back2.yml
	k8c --namespace=d-namespace create -f ${REGULUS_EXAMPLES_DIR}/networkpolicy/tcp80-udp50-backend-policy.yml
	k8nsswitch d-namespace
	k8nscurrent 

}