#!/usr/bin/env bash

HOST_IFC="eth1"
if [ -z "$HOST_IFC" ]; then 
    # If HOST_IFC not specified, we'll use the IP of the default interface through which node talks to the outside world. See: http://stackoverflow.com/questions/21336126/linux-bash-script-to-extract-ip-address
    ip=$(ip route get 8.8.8.8 | awk '/8.8.8.8/ {print $NF}')
else 
    echo "Using $HOST_IFC as primary interface"
    ip=$(ip -f inet -o addr show $HOST_IFC|cut -d\  -f 7 | cut -d/ -f 1)

fi 
if [ -z "$ip" ]
then
    echo "ERROR: no host IP found on interface, please see env-kube.sh"
    exit 1
fi

echo "Using API Server IP: $ip"

# TODO(awander): DNS may require addtional config beyond below
# dns_domain="regulus-test"
# export KUBE_DNS_SERVER_IP="10.255.255.254"
# export KUBE_ENABLE_CLUSTER_DNS=true
# export KUBE_DNS_NAME="${dns_domain}"

export API_HOST_IP="${ip}"

export API_HOST="${API_HOST_IP}"
export ETCD_HOST="${ip}"
export SERVICE_CLUSTER_IP_RANGE="10.255.0.0/16"

export KUBELET_HOST="${ip}"
export NET_PLUGIN="cni"
export NET_PLUGIN_DIR="/etc/cni/net.d"
export API_PORT="8080"
export KUBE_OS_DISTRIBUTION="debian"
export RUNTIME_CONFIG="extensions/v1beta1,extensions/v1beta1/networkpolicies"

if [ -z "$K8_HOME" ]; then
    echo "K8_HOME is not defined, using default: /root/go/src/k8s.io/kubernetes"
    export kubectl="/root/go/src/k8s.io/kubernetes/cluster/kubectl.sh -s ${API_HOST}:${API_PORT}"
else
    export kubectl="$K8_HOME/cluster/kubectl.sh -s ${API_HOST}:${API_PORT}"
fi

# Debugging variables
export LOG_LEVEL=5
# etcd log directory
export ARTIFACTS_DIR="/tmp"
