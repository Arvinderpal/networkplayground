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
package client

import (
	"fmt"
	"net/http"

	"github.com/networkplayground/pkg/option"
)

// Update sends a SET request to the daemon to update its configuration
func (cli Client) Update(opts option.OptionMap) error {
	serverResp, err := cli.R().SetBody(opts).Post("/update")
	if err != nil {
		return fmt.Errorf("error while connecting to daemon: %s", err)
	}

	if serverResp.StatusCode() != http.StatusOK &&
		serverResp.StatusCode() != http.StatusAccepted {
		return processErrorBody(serverResp.Body(), nil)
	}

	return nil
}

// Update sends a SET request to the daemon to update its configuration
func (cli Client) G1MapInsert(opts map[string]string) error {
	serverResp, err := cli.R().SetBody(opts).Post("/g1mapinsert")
	if err != nil {
		return fmt.Errorf("error while connecting to daemon: %s", err)
	}

	if serverResp.StatusCode() != http.StatusOK &&
		serverResp.StatusCode() != http.StatusAccepted {
		return processErrorBody(serverResp.Body(), nil)
	}

	return nil
}

// Update sends a SET request to the daemon to update its configuration
func (cli Client) G2MapUpdate(opts map[string]string) error {
	serverResp, err := cli.R().SetBody(opts).Post("/g2map")
	if err != nil {
		return fmt.Errorf("error while connecting to daemon: %s", err)
	}

	if serverResp.StatusCode() != http.StatusOK &&
		serverResp.StatusCode() != http.StatusAccepted {
		return processErrorBody(serverResp.Body(), nil)
	}

	return nil
}

// Update sends a SET request to the daemon to update its configuration
func (cli Client) G3MapUpdate(opts map[string]string) error {
	serverResp, err := cli.R().SetBody(opts).Post("/g3map")
	if err != nil {
		return fmt.Errorf("error while connecting to daemon: %s", err)
	}

	if serverResp.StatusCode() != http.StatusOK &&
		serverResp.StatusCode() != http.StatusAccepted {
		return processErrorBody(serverResp.Body(), nil)
	}

	return nil
}

// Update sends a SET request to the daemon to update its configuration
func (cli Client) G3MapDelete(opts string) error {
	serverResp, err := cli.R().Delete("/g3map/" + opts)
	if err != nil {
		return fmt.Errorf("error while connecting to daemon: %s", err)
	}

	if serverResp.StatusCode() != http.StatusNoContent &&
		serverResp.StatusCode() != http.StatusNotFound {
		return processErrorBody(serverResp.Body(), nil)
	}

	return nil
}

func (cli Client) G3MapDump() (string, error) {

	serverResp, err := cli.R().Get("/g3maps")
	if err != nil {
		return "", fmt.Errorf("error while connecting to daemon: %s", err)
	}

	if serverResp.StatusCode() != http.StatusNoContent &&
		serverResp.StatusCode() != http.StatusOK {
		return "", processErrorBody(serverResp.Body(), nil)
	}

	if serverResp.StatusCode() == http.StatusNoContent {
		return "", nil
	}

	// var pn policy.Node
	// if err := json.Unmarshal(serverResp.Body(), &pn); err != nil {
	// 	return nil, err
	// }
	return string(serverResp.Body()), nil
}
