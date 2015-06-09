# networkplayground
playing around with ovs, etcd, ...


1. Git clone the following: https://github.com/lowescott/learning-tools
	A. This has two repos of interest: etcd and lxd-ovs. 

2. Copy all files from the etcd repo. The only change is to the servers.yml which should get the ovs box: slowe/ubuntu-1404-x64-ovs

3. Add the box in vagrant:
	vagrant box add slowe/ubuntu-1404-x64-ovs

4. From a terminal window, change into the directory where the files from this directory are stored and run `vagrant up` to bring up the VMs specified in `servers.yml` and `Vagrantfile`.

5. Once Vagrant has finished creating, booting, and provisioning each of the VMs and starting etcd, log into the first system ("etcd-01" by default) using `vagrant ssh etcd-01`.

6. You can test etcd with this command:
		vagrant ssh etcd-01
		etcdctl member list

7. You can check that ovs is install: 
		ovs-vsctl list-br