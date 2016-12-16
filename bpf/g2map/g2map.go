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
package g2map

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
)

// G2Map is an internal representation of an eBPF map
// It's a global (G)map, so only a single instance of it exists
type G2Map struct {
	fd int
}

const (
	MaxKeys = common.G2MapMaxKeys
)

// IPV4 is the __u32 representation of a IPv4 address.
type IPV4 C.__u32

func (m IPV4) String() string {
	return fmt.Sprintf("%d.%d:%d:%d",
		uint32((m & 0x000000FF)),
		uint32((m&0x0000FF00)>>8),
		uint32((m&0x00FF0000)>>16),
		uint32((m&0xFF000000)>>24),
	)
}

// ParseIPV4 parses s
func ParseIPV4(s string) (IPV4, error) {
	ip := net.ParseIP(s)
	if ip == nil {
		return 0, fmt.Errorf("invalid IPV4 address %s", s)
	}
	return IPV4(IPV4(ip[15])<<24 | IPV4(ip[14])<<16 | IPV4(ip[13])<<8 | IPV4(ip[12])), nil
}

// G2Info is an internal representation
// Contains info specific to the usage of the map
type G2Info struct {
	ID         IPV4 /* key */
	TxPktCount uint64
	RxPktCount uint64
}

func (g G2Info) String() string {
	return fmt.Sprintf("id=%d tx=%s rx=%s",
		g.ID,
		g.TxPktCount,
		g.RxPktCount,
	)
}

// Write transforms the relevant data into an G2Info and stores it in G2Map.
func (m *G2Map) Write(id IPV4) error {
	if m == nil {
		return nil
	}

	g2_info := G2Info{
		ID:         id,
		TxPktCount: uint64(0),
		RxPktCount: uint64(0),
	}

	key := uint32(id)

	err := bpf.UpdateElement(m.fd, unsafe.Pointer(&key), unsafe.Pointer(&g2_info), 0)
	if err != nil {
		return err
	}

	return nil
}

// DeleteElement deletes the element with the given id.
func (m *G2Map) DeleteElement(id IPV4) error {
	if m == nil {
		return nil
	}

	// FIXME: errors are currently ignored
	id6 := uint32(id)
	err := bpf.DeleteElement(m.fd, unsafe.Pointer(&id6))

	return err
}

func (m *G2Map) LookupElement(id IPV4) (*G2Info, bool) {

	var entry G2Info
	key := uint32(id)
	err := bpf.LookupElement(m.fd, unsafe.Pointer(&key), unsafe.Pointer(&entry))
	if err != nil {
		return nil, false
	}
	return &entry, true
}

// OpenMap opens the G2Map in the given path.
func OpenMap(path string) (*G2Map, error) {

	fd, _, err := bpf.OpenOrCreateMap(
		path,
		C.BPF_MAP_TYPE_HASH,
		uint32(unsafe.Sizeof(uint32(0))),
		uint32(unsafe.Sizeof(G2Info{})),
		MaxKeys,
	)
	if err != nil {
		return nil, err
	}
	m := new(G2Map)
	m.fd = fd

	return m, nil
}
