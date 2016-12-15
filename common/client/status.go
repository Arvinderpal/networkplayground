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
)

// GlobalStatus sends a GET request to the daemon. Returns the status details of the
// different components running in the daemon.
func (cli Client) GlobalStatus() (string, error) {
	serverResp, err := cli.R().Get("/healthz")
	if err != nil {
		return "", fmt.Errorf("error while connecting to daemon: %s", err)
	}

	if serverResp.StatusCode() != http.StatusOK {
		return "", processErrorBody(serverResp.Body(), nil)
	}
	// TODO (awander): add StatusResponse
	// var resp endpoint.StatusResponse
	// if err := json.Unmarshal(serverResp.Body(), &resp); err != nil {
	// 	return nil, err
	// }
	// return &resp, nil

	return "OK", nil
}
