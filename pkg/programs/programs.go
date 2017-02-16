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
package programs

import (
	"fmt"
	"net"

	"github.com/networkplayground/pkg/mac"
)

type ProgramType int

const (
	ProgramTypeUnspec ProgramType = iota
	ProgramTypeL1
	// MapTypeArray
)

func (t ProgramType) String() string {
	switch t {
	case ProgramTypeL1:
		return "L1"
		// case MapTypeArray:
		// 	return "Array"
	}

	return "Unknown"
}

type ProgramConf struct {
	// These are populated by the EndPoint object:
	DockerID        string  `json:"docker-id"`       // Docker ID.
	HostSideIfIndex int     `json:"interface-index"` // Host's interface index.
	HostSideMAC     mac.MAC `json:"host-side-mac"`   // Host side veth MAC address.
	MAC             mac.MAC `json:"mac"`             // Container MAC address.
	IPv4            net.IP  `json:"ipv4"`            // Container IPv4 address.

	// These are set inside the program code
	RunDir string `json:"rundir"` // where the bpf .o is kept among other things
	LibDir string `json:"libdir"` // where the bpf program code (.c and .sh)  files are
}

type Program interface {
	Type() ProgramType
	Start(userOpts string) error
	Stop(userOpts string) error
	// map functions
	LookupElement(k, mapID string) (string, error)
	UpdateElement(k string, v string, mapID string) error
	DeleteElement(k string, mapID string) error
	Dump2String(mapID string) (string, error)
}

func CreateProgram(dockerID, progType string, conf ProgramConf) (Program, error) {
	switch progType {
	case "L1":
		return NewL1Program(dockerID, conf), nil
		// case "L2":
		// return NewL2Program(), nil
	}
	return nil, fmt.Errorf("Unknown program type: %q", progType)

}
