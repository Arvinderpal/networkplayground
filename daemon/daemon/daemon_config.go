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
	"sync"

	"github.com/networkplayground/bpf/g1map"
	"github.com/networkplayground/bpf/g2map"
	"github.com/networkplayground/pkg/option"
)

const (
	OptionPolicyTracing = "PolicyTracing"
)

var (
	OptionSpecPolicyTracing = option.Option{
		Description: "Enable tracing when resolving policy (Debug)",
	}

	DaemonOptionLibrary = option.OptionLibrary{
		OptionPolicyTracing: &OptionSpecPolicyTracing,
	}

	kvBackend = ""
)

func init() {
}

// Config is the configuration used by Daemon.
type Config struct {
	LibDir         string       // library directory
	RunDir         string       // runtime directory
	G1Map          *g1map.G1Map // G1Map is one global bpf map
	G2Map          *g2map.G2Map // G2Map is one global bpf map
	Device         string       // Receive device
	Tunnel         string       // Tunnel mode
	DockerEndpoint string       // Docker endpoint

	NodeAddress string // Node IPv4 Address in CIDR notation

	K8sEndpoint string // Kubernetes endpoint
	K8sCfgPath  string // Kubeconfig path

	DryMode bool // Do not create BPF maps, devices, ..

	// Options changeable at runtime
	Opts   *option.BoolOptions
	OptsMU sync.RWMutex
}

func NewConfig() *Config {
	return &Config{
		Opts: option.NewBoolOptions(&DaemonOptionLibrary),
	}
}

func (c *Config) IsK8sEnabled() bool {
	return c.K8sEndpoint != "" || c.K8sCfgPath != ""
}
