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
package daemon

import (
	"bufio"
	"fmt"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"

	"github.com/networkplayground/bpf/g1map"
	"github.com/networkplayground/bpf/g2map"
	"github.com/networkplayground/bpf/g3map"
	"github.com/networkplayground/common"
	"github.com/networkplayground/common/types"
	"github.com/networkplayground/pkg/endpoint"
	"github.com/networkplayground/pkg/mac"
	"github.com/networkplayground/pkg/option"

	// dClient "github.com/docker/engine-api/client" -- DEPRECATED
	dClient "github.com/docker/docker/client"
	// dTypes "gi/thub.com/docker/docker/api/types"
	"github.com/op/go-logging"
	"github.com/vishvananda/netlink"
	// k8s "k8s.io/client-go/1.5/kubernetes"
	// k8sRest "k8s.io/client-go/1.5/rest"
	// k8sClientCmd "k8s.io/client-go/1.5/tools/clientcmd"
)

var (
	logger = logging.MustGetLogger("regulus-net")
)

// Daemon is the rugulus daemon
type Daemon struct {
	containersMU      sync.RWMutex
	endpointsMU       sync.RWMutex
	containers        map[string]*types.Container
	endpointsDocker   map[string]*endpoint.Endpoint
	endpointsDockerEP map[string]*endpoint.Endpoint
	conf              *Config
	dockerClient      *dClient.Client
}

func createDockerClient(endpoint string) (*dClient.Client, error) {
	defaultHeaders := map[string]string{"User-Agent": "regulus"}
	return dClient.NewClient(endpoint, "v1.21", nil, defaultHeaders)
}

func (d *Daemon) writeNetdevHeader(dir string) error {
	headerPath := filepath.Join(dir, common.NetdevHeaderFileName)
	f, err := os.Create(headerPath)
	if err != nil {
		return fmt.Errorf("failed to open file %s for writing: %s", headerPath, err)

	}
	defer f.Close()

	fw := bufio.NewWriter(f)
	fw.WriteString(d.conf.Opts.GetFmtList())

	return fw.Flush()
}

func (d *Daemon) init() (err error) {

	globalsDir := filepath.Join(d.conf.RunDir, "globals")
	if err = os.MkdirAll(globalsDir, 0755); err != nil {
		logger.Fatalf("Could not create runtime directory %s: %s", globalsDir, err)
	}

	if err = os.Chdir(d.conf.RunDir); err != nil {
		logger.Fatalf("Could not change to runtime directory %s: \"%s\"",
			d.conf.RunDir, err)
	}

	if !d.conf.DryMode {

		/*
		*
		* TODO(awander): attach bpf here - see call to init.sh; we can compile before hand and just add to default interface
		*
		 */

		d.conf.OptsMU.RLock()
		if err := d.compileBase(); err != nil {
			d.conf.OptsMU.RUnlock()
			return err
		}
		d.conf.OptsMU.RUnlock()

		/*
		*
		* TODO(awander): create our map
		*
		 */
		logger.Info("Creating G1Map...")
		d.conf.G1Map, err = g1map.OpenMap(common.BPFG1Map)
		if err != nil {
			logger.Warningf("Could not create BPF map '%s': %s", common.BPFG1Map, err)
			return err
		}
		logger.Info("Creating G2Map...")
		d.conf.G2Map, err = g2map.OpenMap(common.BPFG2Map)
		if err != nil {
			logger.Warningf("Could not create BPF map '%s': %s", common.BPFG2Map, err)
			return err
		}

		logger.Info("Creating G3Map...")
		// G3Map is a little different from g1/g2 in that it
		// implements the bpf.MapKey and MapValue interface
		// G3Map variable is a global variable
		if _, err := g3map.G3Map.OpenOrCreate(); err != nil {
			return err
		}

	}

	return nil
}

// NewDaemon creates and returns a new Daemon with the parameters set in c.
func NewDaemon(c *Config) (*Daemon, error) {
	if c == nil {
		return nil, fmt.Errorf("Configuration is nil")
	}

	dockerClient, err := createDockerClient(c.DockerEndpoint)
	if err != nil {
		return nil, err
	}

	d := Daemon{
		conf:              c,
		dockerClient:      dockerClient,
		containers:        make(map[string]*types.Container),
		endpointsDocker:   make(map[string]*endpoint.Endpoint),
		endpointsDockerEP: make(map[string]*endpoint.Endpoint),
	}

	if err := d.init(); err != nil {
		logger.Fatalf("Error while initializing daemon: %s\n", err)
	}

	/*
	*
	* TODO(awander): check for stale maps?
	*
	 */
	// walker := func(path string, _ os.FileInfo, _ error) error {
	// 	return d.staleMapWalker(path)
	// }
	// if err := filepath.Walk(common.BPFCiliumMaps, walker); err != nil {
	// 	logger.Warningf("Error while scanning for stale maps: %s", err)
	// }

	return &d, nil
}

func changedOption(key string, value bool, data interface{}) {
}

func (d *Daemon) Update(opts option.OptionMap) error {
	d.conf.OptsMU.Lock()
	defer d.conf.OptsMU.Unlock()

	if err := d.conf.Opts.Validate(opts); err != nil {
		return err
	}

	// changes := d.conf.Opts.Apply(opts, changedOption, d)
	// if changes > 0 {
	// 	if err := d.compileBase(); err != nil {
	// 		logger.Warningf("Unable to recompile base programs: %s\n", err)
	// 	}
	// }

	return nil
}

func (d *Daemon) G1MapInsert(opts map[string]string) (err error) {

	var id uint16
	var mac_hw net.HardwareAddr

	if d.conf.G1Map == nil {
		d.conf.G1Map, err = g1map.OpenMap(common.BPFG1Map)
		if err != nil {
			logger.Warningf("Could not create BPF map '%s': %s", common.BPFG1Map, err)
			return err
		}
	}
	// validate the new key and value pair
	if len(opts) != 1 {
		return fmt.Errorf("Can only insert one key/value at a time. Received: %d ", len(opts))
	}
	for k, v := range opts {
		i, err := strconv.ParseInt(k, 10, 16)
		if err != nil {
			return fmt.Errorf("Key %v is not permittable: %v", k, err)
		}
		id = uint16(i)
		mac_hw, err = net.ParseMAC(v)
		if err != nil {
			return fmt.Errorf("Invalid MAC %v: %v", v, err)
		}
		break
	}

	mac_m := mac.MAC(mac_hw)
	entry, found := d.conf.G1Map.LookupElement(id)
	if found {

		logger.Infof("Found key=%v: old/new v=%v/%v", id, entry.MAC, mac_m)
		// do update here
		return nil
	}

	// insert new entry in map
	if err = d.conf.G1Map.Write(id, mac_m); err != nil {
		logger.Errorf("Insert in G1Map failed for k/v=%s/%s: %v", id, mac_m, err)
		return err
	}

	return nil
}

func (d *Daemon) compileBase() error {
	var args []string
	var mode string

	if err := d.writeNetdevHeader("./"); err != nil {
		logger.Warningf("Unable to write netdev header: %s\n", err)
		return err
	}

	if d.conf.Device != "undefined" {
		if _, err := netlink.LinkByName(d.conf.Device); err != nil {
			logger.Warningf("Link %s does not exist: %s", d.conf.Device, err)
			return err
		}
		mode = "direct"

		args = []string{d.conf.LibDir, d.conf.RunDir, mode, d.conf.Device}
	} else {
		// TODO(awander): add tunnel support!
		args = []string{d.conf.LibDir, d.conf.RunDir, d.conf.Tunnel}
	}

	//./init.sh /usr/lib/regulus /var/run/regulus direct eth1
	out, err := exec.Command(filepath.Join(d.conf.LibDir, "init.sh"), args...).CombinedOutput()
	if err != nil {
		logger.Warningf("Command execution %s %s failed: %s",
			filepath.Join(d.conf.LibDir, "init.sh"),
			strings.Join(args, " "), err)
		logger.Warningf("Command output:\n%s", out)
		return err
	}

	return nil
}
