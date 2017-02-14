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
	"bufio"
	"encoding/hex"
	"fmt"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"unsafe"

	"github.com/networkplayground/common"
	"github.com/networkplayground/pkg/bpf"
	"github.com/vishvananda/netlink"
)

/*
* L1 is a simple program that counts packets recieved by the container.
 The code has these major components:
 1. go code: (this file) is responsible
		i. compiling and starting the bpf program which runs in kernel space
		ii. creating the map resource which will be sharred with kernel bpf and userspace. Note that the c program must know the map name which we define as "ep_l1_" + Docker ID (see MapName)
		iii. userspace program that can interact with the bpf map
 2. C code: (kernel bpf) this code consists of a .c file which performs the 	necessary function:
		i.	the .c file is in the library/bpf/networking/l1 directory
		ii. the .h file is generated here (see writeBPFHeader()) and contains various definitions customized to the container. Since the file is different from one container to another, it is kept in the run directory (/var/run/regulus/<docker id>)
*/

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
	Conf        ProgramConf
	Map         *bpf.Map
}

const (
	L1BPFSrcDir     = "/networking/l1"
	CHeaderFilePath = "/l1.h"
	L1MapNamePrefix = "ep_l1_"
)

func constructMapName(prefix, dockerID string) string {
	return prefix + dockerID
}

func NewL1Program(dockerID string, conf ProgramConf) *L1Program {

	// create l1 map
	l1map := bpf.NewMap(common.L1MapPath+dockerID,
		bpf.MapTypeHash,
		int(unsafe.Sizeof(L1MapKey{})),
		int(unsafe.Sizeof(L1MapValue{})),
		common.MaxKeys)

	// TODO (awander): need to agree on some standard location where all sources will be kept: DefaultLibDir = "/usr/lib/regulus"
	conf.LibDir = "/root/go/src/github.com/networkplayground/bpf"
	conf.RunDir = common.RegulusPath + "/" + dockerID

	return &L1Program{
		ProgramType: ProgramTypeL1,
		Conf:        conf,
		Map:         l1map,
	}
}

func (p *L1Program) Type() ProgramType {
	return p.ProgramType
}

func (p *L1Program) Start() error {

	// compile bpf program and attach it
	err := p.compileBase()
	if err != nil {
		return fmt.Errorf("Start failed: %s", err)
	}
	return nil
}

func (p *L1Program) Stop() error {

	// remove bpf, delete map, ...
	return nil
}

func (p *L1Program) writeBPFHeader() error {
	headerPath := filepath.Join(p.Conf.RunDir, CHeaderFilePath)
	f, err := os.Create(headerPath)
	if err != nil {
		return fmt.Errorf("failed to open file %s for writing: %s", headerPath, err)

	}
	defer f.Close()

	fw := bufio.NewWriter(f)

	fmt.Fprint(fw, "/*\n")

	fmt.Fprintf(fw, ""+
		" * Docker Container ID: %s\n"+
		" * Map Name: %s\n"+
		" * MAC: %s\n"+
		" * IPv4 address: %s\n"+
		" * Host Side MAC: %s\n"+
		" * Host Side Interface Index: %q\n"+
		" */\n\n",
		p.Conf.DockerID, constructMapName(L1MapNamePrefix, p.Conf.DockerID),
		p.Conf.MAC, p.Conf.IPv4.String(),
		p.Conf.HostSideMAC, p.Conf.HostSideIfIndex)

	fmt.Fprintf(fw, "#define DOCKER_ID %s\n", p.Conf.DockerID)
	fmt.Fprintf(fw, "#define MAP_NAME %s\n", constructMapName(L1MapNamePrefix, p.Conf.DockerID))
	fw.WriteString(common.FmtDefineAddress("CONTAINER_MAC", p.Conf.MAC))
	fw.WriteString(common.FmtDefineAddress("CONTAINER_IP", p.Conf.IPv4))
	// fmt.Fprintf(fw, "#define CONTAINER_IP %#x\n", binary.BigEndian.Uint32(p.Conf.IPv4))
	fw.WriteString(common.FmtDefineAddress("CONTAINER_HOST_SIDE_MAC", p.Conf.HostSideMAC))
	fmt.Fprintf(fw, "#define CONTAINER_HOST_SIDE_IFC_IDX %d\n", p.Conf.HostSideIfIndex)

	// Endpoint options
	// NOTE(awander): good way to pass defines directly from cli to bpf:
	// fw.WriteString(ep.Opts.GetFmtList())

	fw.WriteString("\n")

	return fw.Flush()
}

func (p *L1Program) compileBase() error {
	var args []string
	var mode string
	var ifName string

	if err := p.writeBPFHeader(); err != nil {
		return fmt.Errorf("Unable to create BPF header file: %s", err)
	}

	if p.Conf.HostSideIfIndex != 0 {
		hostVeth, err := netlink.LinkByIndex(p.Conf.HostSideIfIndex)
		if err != nil {
			return fmt.Errorf("Error while fetching Link for veth index %v with MAC %s: %s", p.Conf.HostSideIfIndex, p.Conf.HostSideMAC, err)
		}
		ifName = hostVeth.Attrs().Name
		mode = "direct"

		args = []string{p.Conf.LibDir, p.Conf.RunDir, mode, ifName}
	}

	//./init.sh /usr/lib/regulus /var/run/regulus direct eth1
	out, err := exec.Command(filepath.Join(p.Conf.LibDir, L1BPFSrcDir+"/init.sh"), args...).CombinedOutput()
	if err != nil {
		fmt.Errorf("Command execution %s %s failed: %s : Command output:\n%s",
			filepath.Join(p.Conf.LibDir, L1BPFSrcDir+"/init.sh"),
			strings.Join(args, " "), err, out)
		return err
	}

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

func (p *L1Program) UpdateElement(k, v, mapID string) error {

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
		return fmt.Errorf("Map update failed for key=%s: %s", ip, err)
	}
	return nil
}

func (p *L1Program) updateElement(key *L1MapKey, value *L1MapValue) error {
	if _, err := p.Map.OpenOrCreate(); err != nil {
		return err
	}

	return p.Map.Update(key.Convert(), value.Convert())
}

func (p *L1Program) DeleteElement(k, mapID string) error {

	var ip net.IP
	var err error

	ip = net.ParseIP(k)
	if ip == nil {
		return fmt.Errorf("Unable to parsekey: %v", k)
	}

	l1key := NewKey(ip)

	if err = p.deleteElement(l1key); err != nil {
		return fmt.Errorf("Map delete failed for key=%s: %s", ip, err)
	}
	return nil
}

func (p *L1Program) deleteElement(key *L1MapKey) error {
	return p.Map.Delete(key.Convert())
}

// func (p *L1Program) LookupElement(key *L1MapKey) (*L1MapValue, error) {
// 	var elem *L1MapValue

// 	val, err := p.Map.Lookup(key.Convert())
// 	if err != nil {
// 		return nil, err
// 	}

// 	elem = val.(*L1MapValue)

// 	return elem.Convert(), nil
// }

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
