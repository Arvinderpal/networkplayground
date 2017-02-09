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

// ParseKVArgs will parse input strign with format "key=value" and return key, value strings.
func ParseKVArgs(arg string) (string, string, error) {

	optionSplit := strings.SplitN(arg, "=", 2)
	if len(optionSplit) > 1 {
		return optionSplit[0], optionSplit[1], nil
	}
	return "", "", fmt.Errorf("Invalid key/value specified: %s", arg)
}
