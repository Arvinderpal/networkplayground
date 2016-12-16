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
package g1map

/*
#cgo CFLAGS: -I../include
#include <linux/bpf.h>
*/
import "C"

import (
	"fmt"
	"net"
	"unsafe"

	"github.com/networkplayground/common"
	"github.com/networkplayground/pkg/bpf"
	"github.com/networkplayground/pkg/mac"
)

// G1Map is an internal representation of an eBPF map
// It's a global (G)map, so only a single instance of it exists
type G1Map struct {
	fd int
}

const (
	// MaxKeys represents the maximum number of keys in the G1Map.
	MaxKeys = common.G1MapMaxKeys
)

// MAC is the __u64 representation of a MAC address.
type MAC C.__u64

func (m MAC) String() string {
	return fmt.Sprintf("%02X:%02X:%02X:%02X:%02X:%02X",
		uint64((m & 0x0000000000FF)),
		uint64((m&0x00000000FF00)>>8),
		uint64((m&0x000000FF0000)>>16),
		uint64((m&0x0000FF000000)>>24),
		uint64((m&0x00FF00000000)>>32),
		uint64((m&0xFF0000000000)>>40),
	)
}

// ParseMAC parses s only as an IEEE 802 MAC-48.
func ParseMAC(s string) (MAC, error) {
	ha, err := net.ParseMAC(s)
	if err != nil {
		return 0, err
	}
	if len(ha) != 6 {
		return 0, fmt.Errorf("invalid MAC address %s", s)
	}
	return MAC(MAC(ha[5])<<40 | MAC(ha[4])<<32 | MAC(ha[3])<<24 |
		MAC(ha[2])<<16 | MAC(ha[1])<<8 | MAC(ha[0])), nil
}

// G1Info is an internal representation
// Contains info specific to the usage of the map
type G1Info struct {
	G1ID uint16
	MAC  MAC
}

func (g G1Info) String() string {
	return fmt.Sprintf("id=%d mac=%s",
		g.G1ID,
		g.MAC,
	)
}

// Write transforms the relevant data into an G1Info and stores it in G1Map.
func (m *G1Map) Write(id uint16, mac_addr mac.MAC) error {
	if m == nil {
		return nil
	}

	key := uint32(id)

	mac_u64, err := mac_addr.Uint64()
	if err != nil {
		return err
	}

	g1_info := G1Info{
		G1ID: id,
		MAC:  MAC(mac_u64),
	}

	err = bpf.UpdateElement(m.fd, unsafe.Pointer(&key), unsafe.Pointer(&g1_info), 0)
	if err != nil {
		return err
	}

	return nil
}

// DeleteElement deletes the element with the given id from the G1Map.
func (m *G1Map) DeleteElement(id uint16) error {
	if m == nil {
		return nil
	}

	// FIXME: errors are currently ignored
	id6 := uint32(id)
	err := bpf.DeleteElement(m.fd, unsafe.Pointer(&id6))

	return err
}

func (m *G1Map) LookupElement(id uint16) (*G1Info, bool) {

	var entry G1Info
	key := uint32(id)
	err := bpf.LookupElement(m.fd, unsafe.Pointer(&key), unsafe.Pointer(&entry))
	if err != nil {
		return nil, false
	}
	return &entry, true
}

// OpenMap opens the G1Map in the given path.
func OpenMap(path string) (*G1Map, error) {

	fd, _, err := bpf.OpenOrCreateMap(
		path,
		C.BPF_MAP_TYPE_HASH,
		uint32(unsafe.Sizeof(uint32(0))),
		uint32(unsafe.Sizeof(G1Info{})),
		MaxKeys,
	)
	if err != nil {
		return nil, err
	}
	m := new(G1Map)
	m.fd = fd

	return m, nil
}
