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

	"github.com/networkplayground/common"
	"github.com/networkplayground/pkg/endpoint"
	"github.com/networkplayground/pkg/programs"
)

func (d *Daemon) StartProgram(dockerID string, args map[string]string) error {
	logger.Debugf("Starting Program for container %q ...", dockerID)

	// look up ep associated with dockerID
	ep := d.lookupRegulusEndPoint(dockerID)
	if ep == nil {
		return fmt.Errorf("Could not find endpoint associated with %s", dockerID)
	}

	err := validateProgramArgs(args)
	if err != nil {
		return err
	}

	progType := args[common.PROGRAM_ARGS_TYPE_FIELD]

	if prog := lookupProgram(ep, progType); prog != nil {
		return fmt.Errorf("Program already exits")
	}

	newProg, err := programs.CreateProgram(dockerID, progType)
	if err != nil {
		return err
	}

	go newProg.Start()

	ep.Programs = append(ep.Programs, newProg)
	return nil

}

func (d *Daemon) StopProgram(dockerID string, args map[string]string) error {
	logger.Debugf("Stoping Program for container %q ...", dockerID)

	// look up ep associated with dockerID

	// if program exists, stop it

	return nil
}

func (d *Daemon) UpdateMapEntry(dockerID string, args map[string]string) error {
	logger.Debugf("Updating Map entry for container %q ...", dockerID)

	// look up ep associated with dockerID
	ep := d.lookupRegulusEndPoint(dockerID)
	if ep == nil {
		return fmt.Errorf("Could not find endpoint associated with %s", dockerID)
	}

	err := validateProgramArgs(args)
	if err != nil {
		return err
	}

	progType := args[common.PROGRAM_ARGS_TYPE_FIELD]

	prog := lookupProgram(ep, progType)
	if prog == nil {
		return fmt.Errorf("Program {%q} not found for container id {%q}", progType)
	}

	key, value, err := ParseKVArgs(args[common.PROGRAM_ARGS_MAP_KV_PAIR])
	if err != nil {
		return err
	}

	if err := prog.UpdateElement(key, value); err != nil {
		return err
	}

	return nil
}

func (d *Daemon) DeleteMapEntry(dockerID string, args map[string]string) error {
	logger.Debugf("Deleting Map entry for container %q ...", dockerID)
	return nil
}

func (d *Daemon) DumpMap2String(dockerID, progType, mapID string) (string, error) {

	logger.Debugf("Dumping map for container %q ...", dockerID)
	// look up ep associated with dockerID
	ep := d.lookupRegulusEndPoint(dockerID)
	if ep == nil {
		return "", fmt.Errorf("Could not find endpoint associated with %s", dockerID)
	}

	// progType := args[common.PROGRAM_ARGS_TYPE_FIELD]
	prog := lookupProgram(ep, progType)
	if prog == nil {
		return "", fmt.Errorf("Program {%q} not found for container id {%q}", progType)
	}

	// NOTE: this assumes that the map is already open
	dump, err := prog.Dump2String("")
	if err != nil {
		return "", err
	}
	return dump, nil
}

func validateProgramArgs(args map[string]string) error {

	// TODO(awander): need a better way to handle arguments; map[string]string seems clumsy
	if args[common.PROGRAM_ARGS_TYPE_FIELD] == "" {
		return fmt.Errorf("Program type unspecified")
	}
	return nil

}

func lookupProgram(ep *endpoint.Endpoint, progType string) programs.Program {

	for _, prog := range ep.Programs {
		if prog.Type().String() == progType {
			return prog
		}
	}
	return nil
}
