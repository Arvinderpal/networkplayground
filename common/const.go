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
package common

var (
	// Version number needs to be var since we override the value when building
	Version = "dev"
)

const (

	// RegulusPath is the path where regulus operational files are running.
	RegulusPath   = "/var/run/regulus"
	DefaultLibDir = "/usr/lib/regulus"
	// RegulusSock is the socket for the communication between the daemon and client.
	RegulusSock = RegulusPath + "/regulus.sock"
	// DefaultContainerMAC represents a dummy MAC address for the containers.
	DefaultContainerMAC = "AA:BB:CC:DD:EE:FF"

	// BPFMap is the file that contains the BPF Map for the host.
	BPFMapRoot     = "/sys/fs/bpf"
	BPFRegulusMaps = BPFMapRoot + "/tc/globals"
	BPFMap         = BPFRegulusMaps + "/regulus_lxc"

	// RFC3339Milli is the RFC3339 with milliseconds for the default timestamp format
	// log files.
	RFC3339Milli = "2006-01-02T15:04:05.000Z07:00"

	// Miscellaneous dedicated constants

	// GlobalLabelPrefix is the default root path for the policy.
	GlobalLabelPrefix = "io.regulus"

	// GroupFilePath is the unix group file path.
	GroupFilePath = "/etc/group"
	// regulus's unix group name.
	RegulusGroupName = "regulus"

	// CHeaderFileName is the name of the C header file for BPF programs for a
	// particular endpoint.
	CHeaderFileName = "lxc_config.h"
	// Name of the header file used for bpf_netdev.c and bpf_overlay.c
	NetdevHeaderFileName = "netdev_config.h"
)
