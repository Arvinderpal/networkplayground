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
	"strings"
)

// will parse arguments into key and value string pair
func ParseArgsG1Map(arg string) (string, string, error) {

	optionSplit := strings.SplitN(arg, "=", 2)
	key := optionSplit[0]
	if len(optionSplit) > 1 {
		return key, optionSplit[1], nil
	}
	return "", "", fmt.Errorf("No value specified for key: %s", optionSplit[0])
}

func ParseArgsG2Map(arg string) (string, string, error) {

	optionSplit := strings.SplitN(arg, "=", 2)
	key := optionSplit[0]
	if len(optionSplit) > 1 {
		if optionSplit[1] == "insert" || optionSplit[1] == "delete" {
			return key, optionSplit[1], nil
		}
	}
	return "", "", fmt.Errorf("Invalid key/value specified")
}

func ParseArgsG3MapUpdate(arg string) (string, string, error) {

	optionSplit := strings.SplitN(arg, "=", 2)
	key := optionSplit[0]
	if len(optionSplit) > 1 {
		return key, optionSplit[1], nil
	}
	return "", "", fmt.Errorf("Invalid key/value specified")
}
