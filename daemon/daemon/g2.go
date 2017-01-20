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
	"fmt"

	"github.com/networkplayground/bpf/g2map"
	"github.com/networkplayground/common"
)

func (d *Daemon) G2MapUpdate(opts map[string]string) (err error) {

	var ip g2map.IPV4
	var remove bool

	if d.conf.G2Map == nil {
		d.conf.G2Map, err = g2map.OpenMap(common.BPFG2Map)
		if err != nil {
			logger.Warningf("Could not create BPF map '%s': %s", common.BPFG2Map, err)
			return err
		}
	}
	// validate the new key and value pair
	if len(opts) != 1 {
		return fmt.Errorf("Can only insert one key/value at a time. Received: %d ", len(opts))
	}
	for k, v := range opts {
		ip, err = g2map.ParseIPV4(k)
		if err != nil {
			return fmt.Errorf("Key %v is not permittable: %v", k, err)
		}
		if v == "delete" {
			remove = true
		} else {
			remove = false
		}
		break
	}

	_, found := d.conf.G2Map.LookupElement(ip)
	if found {
		logger.Infof("Found key=%v", ip)
	}
	if remove {
		// delete entry
		if found {
			logger.Infof("Deleting entry for %s", ip)
			if err = d.conf.G2Map.DeleteElement(ip); err != nil {
				return err
			}
		} else {
			return fmt.Errorf("No entry found for %s", ip)
		}
	} else {
		// insert entry
		if found {
			// TODO(awander): entry exists, update it
		} else {
			if err = d.conf.G2Map.Write(ip); err != nil {
				logger.Errorf("Insert in G2Map failed for key=%s: %v", ip, err)
				return err
			}
		}
	}
	return nil
}
