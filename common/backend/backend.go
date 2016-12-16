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
	"github.com/networkplayground/pkg/option"
)

type gmaps interface {
	G1MapInsert(map[string]string) error
	G2MapUpdate(map[string]string) error
}

type control interface {
	Ping() (*types.PingResponse, error)
	Update(opts option.OptionMap) error
	GlobalStatus() (string, error)
}

// interface for both client and daemon.
type RegulusBackend interface {
	gmaps
	control
}

// CiliumDaemonBackend is the interface for daemon only.
type RegulusDaemonBackend interface {
	RegulusBackend
}
