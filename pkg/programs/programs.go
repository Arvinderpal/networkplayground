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

import "fmt"

type ProgramType int

const (
	ProgramTypeUnspec ProgramType = iota
	ProgramTypeL1
	// MapTypeArray
)

func (t ProgramType) String() string {
	switch t {
	case ProgramTypeL1:
		return "L1"
		// case MapTypeArray:
		// 	return "Array"
	}

	return "Unknown"
}

type Program interface {
	Type() ProgramType
	Start() error
	Stop() error
	// map functions
	UpdateElement(k string, v string, mapID string) error
	DeleteElement(k string, mapID string) error
	Dump2String(mapID string) (string, error)
}

func CreateProgram(dockerID, progType string) (Program, error) {
	switch progType {
	case "L1":
		return NewL1Program(dockerID), nil
		// case "L2":
		// return NewL2Program(), nil
	}
	return nil, fmt.Errorf("Unknown program type: %q", progType)

}
