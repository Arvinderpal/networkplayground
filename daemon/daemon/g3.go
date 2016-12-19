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
	"net"
	"strconv"

	"github.com/networkplayground/bpf/g3map"
)

func (d *Daemon) G3MapUpdate(opts map[string]string) (err error) {

	var ip net.IP
	var value uint64

	// validate the new key and value pair
	if len(opts) != 1 {
		return fmt.Errorf("Can only insert one key/value at a time. Received: %d ", len(opts))
	}
	for k, v := range opts {
		ip = net.ParseIP(k)
		if ip == nil {
			return fmt.Errorf("Unable to parsekey: %v", k)
		}
		value, err = strconv.ParseUint(v, 10, 16)
		if err != nil {
			return fmt.Errorf("Can't parse value: %s: %s", v, err)
		}
		break
	}

	g3key := g3map.NewKey(ip)
	g3value := g3key.NewValue().(*g3map.G3MapValue)
	g3value.Count = uint16(value)

	// _, err = g3map.LookupElement(g3key)
	// if err != nil {
	// 	log.Infof("Error during lookup of key=%v: %s", ip, err)
	// }
	if err = g3map.UpdateElement(g3key, g3value); err != nil {
		log.Errorf("Update in G3Map failed for key=%s: %v", ip, err)
		return err
	}
	return nil
}

func (d *Daemon) G3MapDump() (string, error) {

	log.Info("Dumping G3map...")
	// NOTE: this assumes that the G3Map is already open
	dump, err := g3map.G3MapDumpParser2String()
	if err != nil {
		return "", err
	}
	return dump, nil
}

func (d *Daemon) G3MapDelete(ip_str string) error {

	log.Debugf("Delete request received for %s", ip_str)
	ip := net.ParseIP(ip_str)
	if ip == nil {
		return fmt.Errorf("Unable to parse key: %v", ip_str)
	}

	g3key := g3map.NewKey(ip)
	if err := g3map.DeleteElement(g3key); err != nil {
		return err
	}
	log.Debugf("Successfully deleted: %s", ip_str)
	return nil
}
