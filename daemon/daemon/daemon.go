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
	"os"
	"path/filepath"

	"github.com/networkplayground/bpf/g1map"
	"github.com/networkplayground/common"
	"github.com/networkplayground/pkg/option"

	// dClient "github.com/docker/engine-api/client"
	"github.com/op/go-logging"
	// "github.com/vishvananda/netlink"
	// k8s "k8s.io/client-go/1.5/kubernetes"
	// k8sRest "k8s.io/client-go/1.5/rest"
	// k8sClientCmd "k8s.io/client-go/1.5/tools/clientcmd"
)

var (
	log = logging.MustGetLogger("regulus-net")
)

// Daemon is the rugulus daemon
type Daemon struct {
	// dockerClient *dClient.Client
	// loadBalancer *types.LoadBalancer
	conf *Config
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
		log.Fatalf("Could not create runtime directory %s: %s", globalsDir, err)
	}

	if err = os.Chdir(d.conf.RunDir); err != nil {
		log.Fatalf("Could not change to runtime directory %s: \"%s\"",
			d.conf.RunDir, err)
	}

	if !d.conf.DryMode {

		/*
		*
		* TODO(awander): attach bpf here - see call to init.sh; we can compile before hand and just add to default interface
		*
		 */

		// d.conf.OptsMU.RLock()
		// if err := d.compileBase(); err != nil {
		// 	d.conf.OptsMU.RUnlock()
		// 	return err
		// }
		// d.conf.OptsMU.RUnlock()

		/*
		*
		* TODO(awander): create our map
		*
		 */
		log.Info("Creating G1Map...")
		d.conf.G1Map, err = g1map.OpenMap(common.BPFG1Map)
		if err != nil {
			log.Warningf("Could not create BPF map '%s': %s", common.BPFG1Map, err)
			return err
		}
		// if _, err := lbmap.Service6Map.OpenOrCreate(); err != nil {
		// 	return err
		// }
	}

	return nil
}

// NewDaemon creates and returns a new Daemon with the parameters set in c.
func NewDaemon(c *Config) (*Daemon, error) {
	if c == nil {
		return nil, fmt.Errorf("Configuration is nil")
	}

	d := Daemon{
		conf: c,
	}

	if err := d.init(); err != nil {
		log.Fatalf("Error while initializing daemon: %s\n", err)
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
	// 	log.Warningf("Error while scanning for stale maps: %s", err)
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
	// 		log.Warningf("Unable to recompile base programs: %s\n", err)
	// 	}
	// }

	return nil
}

/*
func (d *Daemon) compileBase() error {
	var args []string
	var mode string

	if err := d.writeNetdevHeader("./"); err != nil {
		log.Warningf("Unable to write netdev header: %s\n", err)
		return err
	}

	if d.conf.Device != "undefined" {
		if _, err := netlink.LinkByName(d.conf.Device); err != nil {
			log.Warningf("Link %s does not exist: %s", d.conf.Device, err)
			return err
		}

		if d.conf.LBMode {
			mode = "lb"
		} else {
			mode = "direct"
		}

		args = []string{d.conf.LibDir, d.conf.RunDir, d.conf.NodeAddress.String(), d.conf.NodeAddress.IPv4Address.String(), mode, d.conf.Device}
	} else {
		args = []string{d.conf.LibDir, d.conf.RunDir, d.conf.NodeAddress.String(), d.conf.NodeAddress.IPv4Address.String(), d.conf.Tunnel}
	}

	out, err := exec.Command(filepath.Join(d.conf.LibDir, "init.sh"), args...).CombinedOutput()
	if err != nil {
		log.Warningf("Command execution %s %s failed: %s",
			filepath.Join(d.conf.LibDir, "init.sh"),
			strings.Join(args, " "), err)
		log.Warningf("Command output:\n%s", out)
		return err
	}

	return nil
}
*/
