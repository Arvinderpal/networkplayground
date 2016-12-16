//
// Copyright 2016 Authors of Cilium
//
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

import "github.com/networkplayground/common/types"

func (d *Daemon) Ping() (*types.PingResponse, error) {
	d.conf.OptsMU.RLock()
	defer d.conf.OptsMU.RUnlock()
	log.Info("Received Ping Request...")
	return &types.PingResponse{
		NodeAddress: "not-an-address", //d.conf.NodeAddress.String(),
		Opts:        d.conf.Opts,
	}, nil
}