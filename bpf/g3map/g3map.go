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
package g3map

import (
	"bytes"
	"encoding/binary"
	"encoding/hex"
	"fmt"
	"net"
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

// TODO(awander): we should use RLocks for concurrent read acces on G3Map
var (
	G3Map = bpf.NewMap(common.BPFG3Map,
		bpf.MapTypeHash,
		int(unsafe.Sizeof(G3MapKey{})),
		int(unsafe.Sizeof(G3MapValue{})),
		common.G3MapMaxKeys)
)

// TODO(awander): Must match 'struct lb4_key' in "bpf/lib/common.h"
// implements: bpf.MapKey
type G3MapKey struct {
	Address IPv4
}

func (k G3MapKey) Map() *bpf.Map              { return G3Map }
func (k G3MapKey) NewValue() bpf.MapValue     { return &G3MapValue{} }
func (k *G3MapKey) GetKeyPtr() unsafe.Pointer { return unsafe.Pointer(k) }

func (k *G3MapKey) String() string {
	return fmt.Sprintf("%s", k.Address)
}

// Convert between host byte order and map byte order
func (k *G3MapKey) Convert() *G3MapKey {
	n := *k
	// n.Port = common.Swab16(n.Port)
	return &n
}

func (k *G3MapKey) MapDelete() error {
	return k.Map().Delete(k)
}

func NewKey(ip net.IP) *G3MapKey {
	key := G3MapKey{}
	copy(key.Address[:], ip.To4())
	return &key
}

func UpdateElement(key *G3MapKey, value *G3MapValue) error {
	if _, err := key.Map().OpenOrCreate(); err != nil {
		return err
	}

	return key.Map().Update(key.Convert(), value.Convert())
}

func DeleteElement(key *G3MapKey) error {
	return key.Map().Delete(key.Convert())
}

func LookupElement(key *G3MapKey) (*G3MapValue, error) {
	var elem *G3MapValue

	val, err := key.Map().Lookup(key.Convert())
	if err != nil {
		return nil, err
	}

	elem = val.(*G3MapValue)

	return elem.Convert(), nil
}

// TODO(awander): Must match 'struct lb4_service' in "bpf/lib/common.h"
type G3MapValue struct {
	Count uint16
}

func NewG3MapValue(count uint16) *G3MapValue {
	g3 := G3MapValue{
		Count: count, // load some initial count
	}
	return &g3
}

func (s *G3MapValue) GetValuePtr() unsafe.Pointer {
	return unsafe.Pointer(s)
}

func (v *G3MapValue) Convert() *G3MapValue {
	n := *v
	return &n
}

func (v *G3MapValue) String() string {
	return fmt.Sprintf("%s", v.Count)
}

func G3MapDumpParser2String() (string, error) {

	var dump string

	dumpit := func(key []byte, value []byte) (bpf.MapKey, bpf.MapValue, error) {
		// fmt.Printf("Key:\n%sValue:\n%s\n", hex.Dump(key), hex.Dump(value))
		dump = dump + fmt.Sprintf("Key:\n%sValue:\n%s\n", hex.Dump(key), hex.Dump(value))
		return nil, nil, nil
	}

	err := G3Map.Dump(dumpit, nil)
	if err != nil {
		return "", fmt.Errorf("Unable to dump map %s: %s\n", err)
	}
	return dump, nil
}

func G3MapDumpParser(key []byte, value []byte) (bpf.MapKey, bpf.MapValue, error) {
	keyBuf := bytes.NewBuffer(key)
	valueBuf := bytes.NewBuffer(value)
	g3key := G3MapKey{}
	g3val := G3MapValue{}

	if err := binary.Read(keyBuf, binary.LittleEndian, &g3key); err != nil {
		return nil, nil, fmt.Errorf("Unable to convert key: %s\n", err)
	}

	if err := binary.Read(valueBuf, binary.LittleEndian, &g3val); err != nil {
		return nil, nil, fmt.Errorf("Unable to convert key: %s\n", err)
	}

	return g3key.Convert(), g3val.Convert(), nil
}
