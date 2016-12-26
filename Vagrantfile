
# -*- mode: ruby -*-
# vi: set ft=ruby :

# Specify Vagrant version and Vagrant API version
Vagrant.require_version ">= 1.6.0"
VAGRANTFILE_API_VERSION = "2"

# Require 'yaml' module
require 'yaml'

# Read YAML file with VM details (box, CPU, RAM, IP addresses)
# Be sure to edit servers.yml to provide correct IP addresses
servers = YAML.load_file('./netscripts/vxlan/config.yml')

# Require 'erb' module
require 'erb'

# Use config from YAML file to write out templates for etcd overrides
template = File.join(File.dirname(__FILE__), 'etcd.defaults.erb')
content = ERB.new File.new(template).read

etcd_initial_cluster = []
servers.each do |servers|
  etcd_initial_cluster << "#{servers['name']}=http://#{servers['priv_ip']}:2380"
end
servers.each do |servers|
  ip = servers['priv_ip']
  target = File.join(File.dirname(__FILE__), "#{servers['name']}.defaults")
  File.open(target, 'w') { |f| f.write(content.result(binding)) }
end

# Create and configure the VMs
Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  # Always use Vagrant's default insecure key
  config.ssh.insert_key = true
  
  # Iterate through entries in YAML file to create VMs
  servers.each do |servers|
    config.vm.define servers["name"] do |srv|
      # Don't check for box updates
      srv.vm.box_check_update = false
      srv.vm.hostname = servers["name"]
      srv.vm.provider "virtualbox" do |v|
        v.name = servers["name"]
      end
      srv.vm.box = servers["box"]
      srv.vm.boot_timeout = 10000
      
      # Assign an additional static private network
      srv.vm.network "private_network", ip: servers["priv_ip"]
      
      # Specify default synced folder; requires VMware Tools
      # Note shared folders are REQUIRED for the shell provisioning to work
      # rsync (if nfs does not work)
      srv.vm.synced_folder ".", "/root/go/src/github.com/networkplayground", type: "rsync"
      
      # NFS
      #srv.vm.synced_folder ".", "/vagrant", type: "nfs"
      #srv.vm.synced_folder '.', '/root/go/src/github.com/networkplayground', type: "nfs"
      #srv.vm.synced_folder ".", "/root/go/src/github.com/networkplayground/regulus",
      #  :nfs => true,
      #  :mount_options => ['nolock,vers=3,noatime,fsc,actimeo=1']

      #srv.vm.provider "virtualbox" do |vb|
      #   vb.gui = true
      #end
      
      #############
      # BPF SCRIPTS (1): kernel 
      #############
      # v up --provision-with setupkernel
      # If using ubuntu/xenial64: v up --provision-with setupkernel --provider virtualbox

      # srv.vm.provision "setupapt", type:"shell", path: "./netscripts/bpf/setup-apt.sh", privileged: true
      srv.vm.provision "setupkernel", type:"shell", path: "./netscripts/bpf/setup-kernel.sh", privileged: true

      #############
      # Basic Provisioning of VMs + OVS upgrade
      #############
      srv.vm.provision "bootstrap", type:"shell", path: "provision.sh", privileged: true
      
      #############
      # BPF SCRIPTS (2): XDP
      #############
      # v reload --provision-with setupbcc,setupxdp,bootstrap
      srv.vm.provision "setupbcc", type:"shell", path: "./netscripts/bpf/setup-bcc.sh", privileged: true
      srv.vm.provision "setupxdp", type:"shell", path: "./netscripts/bpf/setup-xdp-script.sh", privileged: true

      #############
      # Regulus SCRIPTS
      #############
      # v reload --provision-with regulus
      srv.vm.provision "regulus", type:"shell", path: "./netscripts/bpf/regulus-vagrant.sh", privileged: true

      #############
      # NATS Setup
      #############
      # v reload --provision-with nats
      srv.vm.provision "nats", type:"shell", path: "./netscripts/bpf/nats_setup.sh", privileged: true


      #############
      # OVS SCRIPTS: 
      #############
      # NOTE: we have 2 scripts: setup and simple-network, both of these should
      # be run after the above "bootstrap" has been run and vms rebooted.
      # v up --provision-with bootstrap
      # v reload --provision-with networksetup,simplenetwork

      srv.vm.provision "networksetup", type:"shell", path: "./netscripts/vxlan/setup.sh", args: [servers["clustersubnet"], servers["host_subnet"],  servers["remote1_subnet"], servers["remote2_subnet"], servers["remote1"], servers["remote2"], servers["priv_ip"]], privileged: true
      
      srv.vm.provision "simplenetwork", type:"shell", path: "./netscripts/vxlan/simplenetwork.sh", args: [servers["name"], servers["pod_ip_prefix"], servers["host_subnet"], servers["priv_ip"]], privileged: true

      #############
      # OLD STUFF #
      #############
      #srv.vm.provision "shell", path: "./netscripts/multihost_single_subnet_vxlan.sh", args: [servers["netns1_ip"], servers["remote1"], servers["remote2"]], privileged: true
      
      #srv.vm.provision "shell", path: "./netscripts/multihost_dual_subnet_vxlan_vnid_isolation.sh", args: [servers["pod1_ip"], servers["pod2_ip"],  servers["remotetun1_ip"], servers["remotetun2_ip"], servers["remote1"], servers["remote2"]], privileged: true

      #srv.vm.provision "shell", path: "./netscripts/ipsec_multihost_dual_subnet.sh", args: [servers["netns1_ip"], servers["netns2_ip"],  servers["remote1"], servers["remote2"]], privileged: true
      
      # Configure VMs with RAM and CPUs per settings in servers.yml
      srv.vm.provider :vmware_workstation do |vmw|
        vmw.vmx["memsize"] = servers["ram"]
        vmw.vmx["numvcpus"] = servers["vcpu"]
      end
    end
  end
end
