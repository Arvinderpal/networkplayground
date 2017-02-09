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
package backend

import (
	"github.com/networkplayground/common/types"
	"github.com/networkplayground/pkg/endpoint"
	"github.com/networkplayground/pkg/option"
)

type bpfBackend interface {
	EndpointJoin(ep endpoint.Endpoint) error
	EndpointLeave(dockerID string) error
	EndpointGet(dockerID string) (*endpoint.Endpoint, error)

	EndpointLeaveByDockerEPID(dockerEPID string) error
	EndpointGetByDockerEPID(dockerEPID string) (*endpoint.Endpoint, error)

	EndpointUpdate(dockerID string, opts option.OptionMap) error
	EndpointSave(ep endpoint.Endpoint) error
	EndpointsGet() ([]endpoint.Endpoint, error)
}

type gmaps interface {
	G1MapInsert(map[string]string) error
	G2MapUpdate(map[string]string) error
	G3MapUpdate(map[string]string) error
	G3MapDump() (string, error)
	G3MapDelete(string) error
}

type programs interface {
	StartProgram(dockerID string, args map[string]string) error
	StopProgram(dockerID string, args map[string]string) error
	// GetMapEntry(map[string]string) (string, error)
	UpdateMapEntry(dockerID string, args map[string]string) error
	DeleteMapEntry(dockerID string, args map[string]string) error
	DumpMap2String(dockerID, progType, mapID string) (string, error)
}

type control interface {
	Ping() (*types.PingResponse, error)
	Update(opts option.OptionMap) error
	GlobalStatus() (string, error)
}

// interface for both client and daemon.
type RegulusBackend interface {
	bpfBackend
	gmaps
	programs
	control
}

// CiliumDaemonBackend is the interface for daemon only.
type RegulusDaemonBackend interface {
	RegulusBackend
}
