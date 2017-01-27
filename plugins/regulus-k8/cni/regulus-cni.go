// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"math/rand"
	"net"
	"os/exec"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/networkplayground/common"
	rClient "github.com/networkplayground/common/client"
	"github.com/networkplayground/pkg/endpoint"
	"github.com/networkplayground/pkg/mac"

	"github.com/containernetworking/cni/pkg/ip"
	"github.com/containernetworking/cni/pkg/ipam"
	"github.com/containernetworking/cni/pkg/ns"
	"github.com/containernetworking/cni/pkg/skel"
	cniTypes "github.com/containernetworking/cni/pkg/types"
	"github.com/containernetworking/cni/pkg/version"

	l "github.com/op/go-logging"
	"github.com/vishvananda/netlink"
)

var log = l.MustGetLogger("regulus-net-cni")

// TODO(awander): we should make this configurable
const CNI_PLUGIN_DIR = "/opt/cni/bin"

const (
	TUN_TYPE           = "vxlan"
	TUN_PORT           = "1"
	TUN_PORT_NAME      = "vxlan0"
	EXTERNAL_PORT      = "2"
	EXTERNAL_PORT_NAME = "ext"
	VETH_LEN           = 15

	// # TABLES
	TABLE_CLASSIFY      = "0"
	TABLE_INGRESS_TUN   = "10"
	TABLE_INGRESS_LOCAL = "15"
	TABLE_ACL           = "17"
	TABLE_NAT           = "20"
	TABLE_ROUTER        = "40"
	TABLE_EGRESS_LOCAL  = "50"
	TABLE_EGRESS_TUN    = "55"
	TABLE_EGRESS_EXT    = "58"
)

var (
	ovsVsctlCommand    = "ovs-vsctl"
	ovsOpenFlowCommand = "ovs-ofctl"
	ipCommand          = "/sbin/ip"     // Sometimes changed in unit tests
	sysCtlCommand      = "/sbin/sysctl" // Used to change device properties
	sysEnable          = []byte("1\n")  // Bytes to write to enable features

)

const DockerInterfaceName = "eth0"

var (
	// mydriver *ovsv1Driver
	// Operation lock to prevent race conditions when executing external commands.
	opMutex = sync.Mutex{}
)

type CNIAdditionalArgs struct {
	// NOTE: any changes must be reflected in LoadCNIAdditionalArgs()
	cniTypes.CommonArgs
	PodNameSpace string `json:"k8spodnamespace,omitempty"`
	PodName      string `json:"k8spodname,omitempty"`
	ContainerID  string `json:"k8spodinfracontainerid,omitempty"`
	PodVNID      string `json:"k8spodvnid,omitempty"`
	PodIP        string `json:"k8spodip,omitempty"`
}

// LoadCNIAdditionalArgs loads the additional CNI arguments passed into plugin as part of RuntimeConf
// The arguments are key value pairs separated by ';'
// Ex:  IgnoreUnknown=1;K8S_POD_NAMESPACE=default;K8S_POD_NAME=bb1-von4y;K8S_POD_INFRA_CONTAINER_ID=9eb51f1107c7095....;K8S_POD_VNID=6265105;K8S_POD_IP=192.168.0.1
func LoadCNIAdditionalArgs(args string) (*CNIAdditionalArgs, error) {
	argsStruct := &CNIAdditionalArgs{}
	if args != "" {
		pairs := strings.Split(args, ";")

		// IgnoreUnknown:
		kv := strings.Split(pairs[0], "=")
		if len(kv) != 2 {
			return nil, fmt.Errorf("ARGS: invalid pairs %q", pairs[0])
		}
		s := strings.ToLower(string(kv[1]))
		switch s {
		case "1", "true":
			argsStruct.IgnoreUnknown = true
		case "0", "false":
			argsStruct.IgnoreUnknown = false
		default:
			return nil, fmt.Errorf("Boolean unmarshal error: invalid input %s", s)
		}

		// PodNameSpace:
		kv = strings.Split(pairs[1], "=")
		if len(kv) != 2 {
			return nil, fmt.Errorf("ARGS: invalid pairs %q", pairs[1])
		}
		argsStruct.PodNameSpace = kv[1]

		// Pod Name:
		kv = strings.Split(pairs[2], "=")
		if len(kv) != 2 {
			return nil, fmt.Errorf("ARGS: invalid pairs %q", pairs[2])
		}
		argsStruct.PodName = kv[1]

		// ContainerID:
		kv = strings.Split(pairs[3], "=")
		if len(kv) != 2 {
			return nil, fmt.Errorf("ARGS: invalid pairs %q", pairs[3])
		}
		argsStruct.ContainerID = kv[1]

		// PodVNID:
		kv = strings.Split(pairs[4], "=")
		if len(kv) != 2 {
			return nil, fmt.Errorf("ARGS: invalid pairs %q", pairs[4])
		}
		argsStruct.PodVNID = kv[1]

		// PodIP:
		kv = strings.Split(pairs[5], "=")
		if len(kv) != 2 {
			return nil, fmt.Errorf("ARGS: invalid pairs %q", pairs[5])
		}
		argsStruct.PodIP = kv[1]
	}

	return argsStruct, nil
}

// Utility to debug the output from commands executed
func debugCommandOutput(cmd *exec.Cmd) (err error) {
	log.Infof("Executing: %s %s", cmd.Path, strings.Join(cmd.Args[1:], " "))
	out, err := cmd.CombinedOutput()
	if err != nil {
		log.Errorf("ERROR: %s error: %s %q", cmd.Path, err, string(out))
	}
	return err
}

func init() {
	common.SetupLOG(log, "DEBUG")
	rand.Seed(time.Now().UTC().UnixNano())
	// this ensures that main runs only on main thread (thread group leader).
	// since namespace ops (unshare, setns) are done for a single thread, we
	// must ensure that the goroutine does not jump from OS thread to thread
	runtime.LockOSThread()
	log.Infof("init() complete")
}

// type regulusNetConf struct {
// 	types.NetConf
// 	CniVersion string `json:"cniVersion"`
// 	Name       string `json:"name"`
// 	Type       string `json:"type"`
// 	BrName     string `json:"bridge"`
// 	AddIf      string `json:"addIf"`
// 	IsGW       bool   `json:"isGateway"`
// 	IPMasq     bool   `json:"ipMasq"`
// 	MTU        int    `json:"mtu"`
// 	IPAM       struct {
// 		Type    string `json:"type"`
// 		Subnet  string `json:"subnet"`
// 		Gateway string `json:"gateway"`
// 	} `json:"ipam"`
// }

type regulusNetConf struct {
	cniTypes.NetConf
	BrName string `json:"bridge"`
	MTU    int    `json:"mtu"`
}

func loadNetConf(bytes []byte) (*regulusNetConf, error) {
	n := &regulusNetConf{}
	if err := json.Unmarshal(bytes, n); err != nil {
		return nil, fmt.Errorf("failed to load netconf: %v", err)
	}
	return n, nil
}

func setupVeth(netns string, ifName string, mtu int, containerID string, ep *endpoint.Endpoint) (string, error) {
	var hostVethName string

	log.Infof("setupVeth() called: %v, %v, %v", netns, ifName, mtu)

	err := ns.WithNetNSPath(netns, func(hostNS ns.NetNS) error {
		// Create the veth pair in the container and move host end into host netns
		var err error
		hostVethName, err = setupPodVeth(ifName, mtu, hostNS, containerID, ep)
		if err != nil {
			return err
		}
		return nil
	})
	if err != nil {
		return "", err
	}

	// need to lookup hostVeth again as its index has changed during ns move
	hostVeth, err := netlink.LinkByName(hostVethName)
	if err != nil {
		return "", fmt.Errorf("failed to lookup %q: %v", hostVethName, err)
	}
	ep.NodeMAC = mac.MAC(hostVeth.Attrs().HardwareAddr)
	ep.IfIndex = hostVeth.Attrs().Index

	// TODO(awander): we should make this the default route
	// ip route add default dev <internal veth>

	return hostVethName, nil
}

func calcGatewayIP(ipn *net.IPNet) net.IP {
	nid := ipn.IP.Mask(ipn.Mask)
	return ip.NextIP(nid)
}

// ovsAddPort: adds a port to the ovs bridge
func ovsAddPort(brName, portName string, ipNet *net.IPNet, portNum int, vnid string) error {
	opMutex.Lock()
	defer opMutex.Unlock()

	// the shell scripts must be in same dir as the cni executables
	cmd := exec.Command(CNI_PLUGIN_DIR+"/ovsv1.sh", "add", brName, portName, ipNet.IP.String(), strconv.Itoa(portNum), vnid)
	err := debugCommandOutput(cmd)
	if err != nil {
		return err
	}

	return nil
}

// deleteDockerBrInterface deletes the docker interface if one exists inside the pod
// We assume that that only a single interface exists and is labeled eth0. There is nothing
// here checking that in fact it is infact connected to the docker bridge.
// TODO(awander): we should infact be deleting all interfaces that may exist (excluding LB);
// that is, only our ovs interface should be made available to pods.
// Also, this is approach is *not* the cleanest. The following warnings show up in kubelet
// W0829 15:47:37.802582   36398 summary.go:346] Missing default interface "eth0" for pod:default_bb1
/*
func deleteDockerBrInterface(netns string) error {

	err := ns.WithNetNSPath(netns, false, func(hostNS *os.File) error {
		err := ip.DelLinkByName(DockerInterfaceName)
		if !strings.Contains(fmt.Sprintf("%s", err), "failed to lookup") {
			// ignore not found errors, but report any other error
			return err
		}
		return nil
	})

	return err
}
*/

// ovsDeletePort: deletes a port from the ovs bridge
func ovsDeletePort(brName string, portName string, ipNet *net.IPNet, portNum int, vnid string) error {
	opMutex.Lock()
	defer opMutex.Unlock()

	// the shell scripts must be in same dir as the cni executables
	cmd := exec.Command(CNI_PLUGIN_DIR+"/ovsv1.sh", "del", brName, portName, ipNet.IP.String(), strconv.Itoa(portNum), vnid)
	err := debugCommandOutput(cmd)
	if err != nil {
		return err
	}

	return nil
}

func genHostVethName(containerID string) string {
	// TODO(awander): change to just "ve-" and use 8 chars from ID
	return "veth-" + containerID[0:VETH_LEN-5]
}

// Use containerID to generate outer veth (host). Container creation should
// fail if there is a collision with the containerID prefix used.
func genVeth(name string, mtu int, containerID string) (netlink.Link, string, netlink.Link, error) {
	hostVethName := genHostVethName(containerID)

	if getVeth(hostVethName) != nil {
		// this could be caused by a name conflict which is certainly possible
		// since we use only 6 chars of the containerID
		return nil, "", nil, fmt.Errorf("Container veth name (%v) already exists for container: %s", hostVethName, containerID)
	}
	contVeth, err := makeVethPair(name, hostVethName, mtu)
	if err != nil {
		return nil, "", nil, fmt.Errorf("Failed to make veth pair: %v", err)
	}

	hostVeth, err := netlink.LinkByName(hostVethName)
	if err != nil {
		return nil, "", nil, fmt.Errorf("unable to lookup veth just created: %s", err)
	}

	return contVeth, hostVethName, hostVeth, nil
}

// Derive the veth from the container ID. We start by checking the longest
// possible veth first. This way chances of identifying the wrong one are
// lower. TODO: elminate the very small possibility of deleting the wrong veth.
// This could happen if two containers have almost identical containerIDs,
// e.g., cotainerA=eabcddefadfad and containerB=eabcddeaester.  For containerA
// we would generate veth-eabcdd and for containerB veth-eabcdd-e. Now, if we
// delete containerA, we will mistakenly identify veth-eabcdd-e as belonging to
// containerA.
func getHostSideVeth(containerID string) netlink.Link {
	name := genHostVethName(containerID)
	hostveth := getVeth(name)
	if hostveth != nil {
		return hostveth
	}
	return nil
}

func getVeth(name string) netlink.Link {
	veth, err := netlink.LinkByName(name)
	if err != nil {
		return nil
	}
	return veth
}

// Create the veth-pari
func makeVethPair(name, peer string, mtu int) (netlink.Link, error) {
	veth := &netlink.Veth{
		LinkAttrs: netlink.LinkAttrs{
			Name:  name,
			Flags: net.FlagUp,
			MTU:   mtu,
		},
		PeerName: peer,
	}
	if err := netlink.LinkAdd(veth); err != nil {
		return nil, err
	}

	return veth, nil
}

// setupPodVeth sets up the veth pair
// NOTE:
// 	- contVethName: name of the (internal) veth that will placed inside the container -- e.g. eth0
// 	- hostVethName is generated and is the name of the (external) veth in the host netns.
//
// Additional Notes:
// This is copied from CNI but uses our genVeth(...) methode instead of CNI's
// makeVeth(...). We no longer rely on CNI to generate the host part of the
// veth pair but generate our own based on the POD-id. This way we do not need
// to store the veth name for deletion later.
func setupPodVeth(contVethName string, mtu int, hostNS ns.NetNS, containerID string, ep *endpoint.Endpoint) (string, error) {

	var hostVethName string

	contVeth, hostVethName, hostVeth, err := genVeth(contVethName, mtu, containerID)
	if err != nil {
		return "", fmt.Errorf("Error while generating veths: %s", err)
	}

	if err = netlink.LinkSetUp(contVeth); err != nil {
		return "", fmt.Errorf("failed to set %q up: %v", contVethName, err)
	}

	if err = netlink.LinkSetNsFd(hostVeth, int(hostNS.Fd())); err != nil {
		return "", fmt.Errorf("failed to move veth to host netns: %v", err)
	}

	err = hostNS.Do(func(_ ns.NetNS) error {
		hostVeth, err := netlink.LinkByName(hostVethName)
		if err != nil {
			return fmt.Errorf("failed to lookup %q in %q: %v", hostVethName, hostNS.Path(), err)
		}

		if err = netlink.LinkSetUp(hostVeth); err != nil {
			return fmt.Errorf("failed to set %q up: %v", hostVethName, err)
		}
		return nil
	})

	ep.MAC = mac.MAC(contVeth.Attrs().HardwareAddr)
	ep.IfName = contVeth.Attrs().Name

	return hostVethName, nil
}

func cmdAdd(args *skel.CmdArgs) error {
	log.Infof("ovsv1:cmdAdd called with args %v ", args)

	// start by removing the interface to docker-br
	// TODO(awander): make sure this works
	// err := deleteDockerBrInterface(args.Netns)
	// if err != nil {
	//	return err
	// }

	n, err := loadNetConf(args.StdinData)
	if err != nil {
		return err
	}

	c, err := rClient.NewDefaultClient()
	if err != nil {
		return fmt.Errorf("error while starting cilium-client: %s", err)
	}

	var ep endpoint.Endpoint
	hostVethName, err := setupVeth(args.Netns, args.IfName, n.MTU, args.ContainerID, &ep)
	if err != nil {
		return err
	}

	// run the IPAM plugin and get back the config to apply
	result, err := ipam.ExecAdd(n.IPAM.Type, args.StdinData)
	if err != nil {
		return err
	}

	// Change subnet mask to /16 to allow pod-to-pod communication.
	result.IP4.IP.Mask = net.IPv4Mask(0xff, 0xff, 0x00, 0x00)

	if result.IP4 == nil {
		return errors.New("IPAM plugin returned missing IPv4 config")
	}

	// allocate a port number used to identify this port on ovs
	ovsPortNum := ipToPortMapper(result.IP4.IP.IP)
	// ovsPortNum, err := mydriver.state.allocatePort()
	// if err != nil {
	// 	return err
	// }
	log.Infof("ovsv1:cmdAdd allocating port %v for ip %s on %s", ovsPortNum, result.IP4.IP.IP, n.BrName)

	// let's parse the additional args which include the VNID of the pod
	additionalArgs, err := LoadCNIAdditionalArgs(args.Args)
	if err != nil {
		return err
	}
	log.Infof("CNI Additional Arguments: %+v", additionalArgs)

	log.Debugf("Adding port %s to ovs", hostVethName)
	// connect host veth end to the bridge
	// err = ovsAddPort(n.BrName, hostVethName, &result.IP4.IP, ovsPortNum, additionalArgs.PodVNID)
	// if err != nil {
	// 	log.Errorf("ERROR: ovsv1 ovsAddPort: could not add ovs port: %s -- err: %v", hostVethName, err)
	// 	return err
	// }

	err = ns.WithNetNSPath(args.Netns, func(hostNS ns.NetNS) error {
		return ipam.ConfigureIface(args.IfName, result)
	})
	if err != nil {
		return err
	}

	ep.IPv4 = result.IP4.IP.IP
	// ep.NodeIP = ipamConf.IP6.Gateway  // TODO(awander): what to do here?
	ep.DockerID = args.ContainerID

	log.Infof("Creating Endpoint: ID %s IP: %s MAC: %s NodeMAC: %s IfIndex: %v IfName: %s  ", ep.DockerID, ep.IPv4, ep.MAC, ep.NodeMAC, ep.IfIndex, ep.IfName)

	if err = c.EndpointJoin(ep); err != nil {
		return fmt.Errorf("unable to create eBPF map: %s", err)
	}

	result.DNS = n.DNS
	return result.Print()
}

// For proper cleanup, we need the following:
// 1. external port name to delete ovs port -> can be generated from the containerID (passed via CNI)
// 2. IP address allocated to delete flow rules -> passed via CNI
func cmdDel(args *skel.CmdArgs) error {
	log.Infof("ovsv1:cmdDel called with args %v ", args)

	n, err := loadNetConf(args.StdinData)
	if err != nil {
		return err
	}

	c, err := rClient.NewDefaultClient()
	if err != nil {
		return fmt.Errorf("error while starting regulus-client: %s", err)
	}

	ep, err := c.EndpointGet(args.ContainerID)
	if err != nil {
		return fmt.Errorf("error while retrieving endpoint from regulus daemon: %s", err)
	}
	if ep == nil {
		return fmt.Errorf("endpoint with container ID %s not found", args.ContainerID)
	}

	log.Infof("Deleting Endpoint: ID %s IP: %s MAC: %s NodeMAC: %s IfIndex: %v IfName: %s  ", ep.DockerID, ep.IPv4, ep.MAC, ep.NodeMAC, ep.IfIndex, ep.IfName)

	// Release IP address so that it can be reused
	err = ipam.ExecDel(n.IPAM.Type, args.StdinData)
	if err != nil {
		return err
	}

	additionalArgs, err := LoadCNIAdditionalArgs(args.Args)

	// get the port allocated for this pod
	ipaddr, netaddr, err := net.ParseCIDR(additionalArgs.PodIP + "/32")
	if err != nil {
		return err
	}
	ovsPortNum := ipToPortMapper(ipaddr)

	hostVeth := getHostSideVeth(args.ContainerID)
	if hostVeth == nil {
		return fmt.Errorf("Could not find veth for pod %v", args.ContainerID)
	}

	log.Debugf("ovs delete port on br: %s port name: %s addr: %s port #: %v", n.BrName, hostVeth.Attrs().Name, netaddr, ovsPortNum)
	// TODO(awander): enable this when we have ovs setup
	// ovsDeletePort(n.BrName, hostVeth.Attrs().Name, netaddr, ovsPortNum, additionalArgs.PodVNID)

	if err := c.EndpointLeave(ep.DockerID); err != nil {
		log.Warningf("leaving the endpoint failed: %s\n", err)
	}

	return ns.WithNetNSPath(args.Netns, func(hostNS ns.NetNS) error {
		return ip.DelLinkByName(args.IfName)
	})
}

func main() {

	log.Infof("entering main()")

	// PluginMain will grab the various CNI env variables and then call
	// our cmdAdd/Del functions above; passing in the env vars as argument
	// skel.PluginMain(cmdAdd, cmdDel)
	skel.PluginMain(cmdAdd, cmdDel, version.Legacy)

	log.Infof("exiting main()")
}
