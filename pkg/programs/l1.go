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
	"encoding/hex"
	"fmt"
	"net"
	"strconv"
	"unsafe"

	"github.com/networkplayground/common"
	"github.com/networkplayground/pkg/bpf"
)

// binary representation for encoding in binary structs
type IPv4 [4]byte

func (v4 IPv4) IP() net.IP {
	return v4[:]
}

func (v4 IPv4) String() string {
	return v4.IP().String()
}

type L1Program struct {
	ProgramType ProgramType
	Map         *bpf.Map
}

func NewL1Program(dockerID string) *L1Program {

	// create l1 map
	l1map := bpf.NewMap(common.L1MapPath+dockerID,
		bpf.MapTypeHash,
		int(unsafe.Sizeof(L1MapKey{})),
		int(unsafe.Sizeof(L1MapValue{})),
		common.MaxKeys)

	return &L1Program{
		ProgramType: ProgramTypeL1,
		Map:         l1map,
	}
}

func (p *L1Program) Type() ProgramType {
	return p.ProgramType
}

func (p *L1Program) Start() error {

	// compile bpf program and attach it
	return nil
}

func (p *L1Program) Stop() error {
	return nil
}

// NOTE(awander): Must match 'struct lb4_key' in "bpf/lib/common.h"
// implements: bpf.MapKey
type L1MapKey struct {
	Address IPv4
}

// func (k L1MapKey) Map() *bpf.Map              { return prog }
func (k L1MapKey) NewValue() bpf.MapValue     { return &L1MapValue{} }
func (k *L1MapKey) GetKeyPtr() unsafe.Pointer { return unsafe.Pointer(k) }

func (k *L1MapKey) String() string {
	return fmt.Sprintf("%s", k.Address)
}

// Convert between host byte order and map byte order
func (k *L1MapKey) Convert() *L1MapKey {
	n := *k
	// n.Port = common.Swab16(n.Port)
	return &n
}

// func (k *L1MapKey) MapDelete() error {
// 	return k.Map().Delete(k)
// }

func NewKey(ip net.IP) *L1MapKey {
	key := L1MapKey{}
	copy(key.Address[:], ip.To4())
	return &key
}

// TODO(awander): Must match 'struct lb4_service' in "bpf/lib/common.h"
type L1MapValue struct {
	Count uint16
}

func NewL1MapValue(count uint16) *L1MapValue {
	l1 := L1MapValue{
		Count: count, // load some initial count
	}
	return &l1
}

func (s *L1MapValue) GetValuePtr() unsafe.Pointer {
	return unsafe.Pointer(s)
}

func (v *L1MapValue) Convert() *L1MapValue {
	n := *v
	return &n
}

func (v *L1MapValue) String() string {
	return fmt.Sprintf("%s", v.Count)
}

func (p *L1Program) UpdateElement(k, v string) error {

	var ip net.IP
	var err error
	var value uint64

	ip = net.ParseIP(k)
	if ip == nil {
		return fmt.Errorf("Unable to parsekey: %v", k)
	}
	value, err = strconv.ParseUint(v, 10, 16)
	if err != nil {
		return fmt.Errorf("Can't parse value: %s: %s", v, err)
	}

	l1key := NewKey(ip)
	l1value := l1key.NewValue().(*L1MapValue)
	l1value.Count = uint16(value)

	if err = p.updateElement(l1key, l1value); err != nil {
		return fmt.Errorf("Map update failed for key=%s: %v", ip, err)
	}
	return nil
}

func (p *L1Program) updateElement(key *L1MapKey, value *L1MapValue) error {
	if _, err := p.Map.OpenOrCreate(); err != nil {
		return err
	}

	return p.Map.Update(key.Convert(), value.Convert())
}

func (p *L1Program) DeleteElement(key *L1MapKey) error {
	return p.Map.Delete(key.Convert())
}

func (p *L1Program) LookupElement(key *L1MapKey) (*L1MapValue, error) {
	var elem *L1MapValue

	val, err := p.Map.Lookup(key.Convert())
	if err != nil {
		return nil, err
	}

	elem = val.(*L1MapValue)

	return elem.Convert(), nil
}

// Dump2String dumps the entire map object in string format
// Note that input - mapID - is ignored since we only have a single map
func (p *L1Program) Dump2String(mapID string) (string, error) {

	var dump string

	dumpit := func(key []byte, value []byte) (bpf.MapKey, bpf.MapValue, error) {
		// fmt.Printf("Key:\n%sValue:\n%s\n", hex.Dump(key), hex.Dump(value))
		dump = dump + fmt.Sprintf("Key:\n%sValue:\n%s\n", hex.Dump(key), hex.Dump(value))
		return nil, nil, nil
	}

	err := p.Map.Dump(dumpit, nil)
	if err != nil {
		return "", fmt.Errorf("Unable to dump map %s: %s\n", err)
	}
	return dump, nil
}

// func G3MapDumpParser(key []byte, value []byte) (bpf.MapKey, bpf.MapValue, error) {
// 	keyBuf := bytes.NewBuffer(key)
// 	valueBuf := bytes.NewBuffer(value)
// 	g3key := G3MapKey{}
// 	g3val := G3MapValue{}

// 	if err := binary.Read(keyBuf, binary.LittleEndian, &g3key); err != nil {
// 		return nil, nil, fmt.Errorf("Unable to convert key: %s\n", err)
// 	}

// 	if err := binary.Read(valueBuf, binary.LittleEndian, &g3val); err != nil {
// 		return nil, nil, fmt.Errorf("Unable to convert key: %s\n", err)
// 	}

// 	return g3key.Convert(), g3val.Convert(), nil
// }
