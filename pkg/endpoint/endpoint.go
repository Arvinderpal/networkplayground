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
package endpoint

import (
	"fmt"
	"net"
	"strings"
	"sync"
	"time"

	// "github.com/cilium/cilium/bpf/policymap"
	"github.com/networkplayground/pkg/mac"
	"github.com/networkplayground/pkg/option"
	"github.com/networkplayground/pkg/programs"

	"github.com/op/go-logging"
)

var (
	log = logging.MustGetLogger("regulus-endpoint")
)

const (
	maxLogs = 256
)

// Endpoint contains all the details for a particular LXC and the host interface to where
// is connected to.
type Endpoint struct {
	// ID               uint16 `json:"id"`                 // Endpoint ID.
	DockerID         string `json:"docker-id"`          // Docker ID.
	DockerNetworkID  string `json:"docker-network-id"`  // Docker network ID.
	DockerEndpointID string `json:"docker-endpoint-id"` // Docker endpoint ID.

	IfName  string  `json:"interface-name"`  // Container's interface name.
	MAC     mac.MAC `json:"mac"`             // Container MAC address.
	IPv4    net.IP  `json:"ipv4"`            // Container IPv4 address.
	IfIndex int     `json:"interface-index"` // Host's interface index.

	NodeMAC mac.MAC `json:"node-mac"` // Node MAC address.
	NodeIP  net.IP  `json:"node-ip"`  // Node IPv4/6 address.

	// BPFs attached to container
	Programs []programs.Program `json:"-"`

	// Consumable       *policy.Consumable    `json:"consumable"`
	Opts   *option.BoolOptions `json:"options"` // Endpoint bpf options.
	Status *EndpointStatus     `json:"status,omitempty"`
}

type statusLog struct {
	Status    Status    `json:"status"`
	Timestamp time.Time `json:"timestamp"`
}

type EndpointStatus struct {
	Log     []*statusLog `json:"log,omitempty"`
	Index   int          `json:"index"`
	indexMU sync.RWMutex
}

func (e *EndpointStatus) lastIndex() int {
	lastIndex := e.Index - 1
	if lastIndex < 0 {
		return maxLogs - 1
	}
	return lastIndex
}

func (e *EndpointStatus) getAndIncIdx() int {
	idx := e.Index
	e.Index++
	if e.Index >= maxLogs {
		e.Index = 0
	}
	return idx
}

func (e *EndpointStatus) addStatusLog(s *statusLog) {
	idx := e.getAndIncIdx()
	if len(e.Log) < maxLogs {
		e.Log = append(e.Log, s)
	} else {
		e.Log[idx] = s
	}
}

func (e *EndpointStatus) String() string {
	e.indexMU.RLock()
	defer e.indexMU.RUnlock()
	if len(e.Log) > 0 {
		lastLog := e.Log[e.lastIndex()]
		if lastLog != nil {
			return fmt.Sprintf("%s", lastLog.Status.Code)
		}
	}
	return OK.String()
}

func (e *EndpointStatus) DumpLog() string {
	e.indexMU.RLock()
	defer e.indexMU.RUnlock()
	logs := []string{}
	for i := e.lastIndex(); ; i-- {
		if i < 0 {
			i = maxLogs - 1
		}
		if i < len(e.Log) && e.Log[i] != nil {
			logs = append(logs, fmt.Sprintf("%s - %s",
				e.Log[i].Timestamp.Format(time.RFC3339), e.Log[i].Status))
		}
		if i == e.Index {
			break
		}
	}
	if len(logs) == 0 {
		return OK.String()
	}
	return strings.Join(logs, "\n")
}

func (es *EndpointStatus) DeepCopy() *EndpointStatus {
	cpy := &EndpointStatus{}
	es.indexMU.RLock()
	defer es.indexMU.RUnlock()
	cpy.Index = es.Index
	cpy.Log = []*statusLog{}
	for _, v := range es.Log {
		cpy.Log = append(cpy.Log, v)
	}
	return cpy
}

func (e *Endpoint) DeepCopy() *Endpoint {
	cpy := &Endpoint{
		// ID:               e.ID,
		DockerID:         e.DockerID,
		DockerNetworkID:  e.DockerNetworkID,
		DockerEndpointID: e.DockerEndpointID,
		IfName:           e.IfName,
		MAC:              make(mac.MAC, len(e.MAC)),
		IPv4:             make(net.IP, len(e.IPv4)),
		IfIndex:          e.IfIndex,
		NodeMAC:          make(mac.MAC, len(e.NodeMAC)),
		NodeIP:           make(net.IP, len(e.NodeIP)),
		// PortMap:          make([]PortMap, len(e.PortMap)),
	}

	copy(cpy.MAC, e.MAC)
	copy(cpy.IPv4, e.IPv4)
	copy(cpy.NodeMAC, e.NodeMAC)
	copy(cpy.NodeIP, e.NodeIP)
	// copy(cpy.PortMap, e.PortMap)

	// TODO(awander): should be copy the Programs as well?

	// if e.GenericMap != nil {
	// 	cpy.GenericMap = e.GenericMap.DeepCopy()
	// }
	if e.Opts != nil {
		cpy.Opts = e.Opts.DeepCopy()
	}
	if e.Status != nil {
		cpy.Status = e.Status.DeepCopy()
	}

	return cpy
}

func (ep *Endpoint) SetDefaultOpts(opts *option.BoolOptions) {
	// if ep.Opts == nil {
	// 	ep.Opts = option.NewBoolOptions(&EndpointOptionLibrary)
	// }
	// if ep.Opts.Library == nil {
	// 	ep.Opts.Library = &EndpointOptionLibrary
	// }

	// if opts != nil {
	// 	for k := range EndpointMutableOptionLibrary {
	// 		ep.Opts.Set(k, opts.IsEnabled(k))
	// 	}
	// 	// Lets keep this here to prevent users to hurt themselves.
	// 	ep.Opts.SetIfUnset(OptionLearnTraffic, false)
	// }
}

func (e *Endpoint) LogStatus(code StatusCode, msg string) {
	e.Status.indexMU.Lock()
	defer e.Status.indexMU.Unlock()
	sts := &statusLog{
		Status: Status{
			Code: code,
			Msg:  msg,
		},
		Timestamp: time.Now(),
	}
	e.Status.addStatusLog(sts)
}

func (e *Endpoint) LogStatusOK(msg string) {
	e.Status.indexMU.Lock()
	defer e.Status.indexMU.Unlock()
	sts := &statusLog{
		Status:    NewStatusOK(msg),
		Timestamp: time.Now(),
	}
	e.Status.addStatusLog(sts)
}

func (e *Endpoint) GenProgramConf() programs.ProgramConf {

	return programs.ProgramConf{
		DockerID:        e.DockerID,
		HostSideIfIndex: e.IfIndex,
		HostSideMAC:     e.NodeMAC,
		MAC:             e.MAC,
		IPv4:            e.IPv4,
	}

}
