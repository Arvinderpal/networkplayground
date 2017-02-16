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

func (cli Client) StartProgram(dockerID string, args map[string]string) error {

	serverResp, err := cli.R().SetBody(args).Post("/program/" + dockerID)
	if err != nil {
		return fmt.Errorf("error while connecting to daemon: %s", err)
	}

	if serverResp.StatusCode() != http.StatusOK &&
		serverResp.StatusCode() != http.StatusAccepted {
		return processErrorBody(serverResp.Body(), nil)
	}

	return nil
}

func (cli Client) StopProgram(dockerID string, args map[string]string) error {

	serverResp, err := cli.R().SetBody(args).Delete("/program/" + dockerID)
	if err != nil {
		return fmt.Errorf("error while connecting to daemon: %s", err)
	}

	if serverResp.StatusCode() != http.StatusOK &&
		serverResp.StatusCode() != http.StatusAccepted {
		return processErrorBody(serverResp.Body(), nil)
	}

	return nil
}

func (cli Client) LookupMapEntry(dockerID, progType, mapID, key string) (string, error) {

	serverResp, err := cli.R().Get("/programmap/" + dockerID + "/" + progType + "/" + mapID + "/" + key)
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

	return string(serverResp.Body()), nil
}

func (cli Client) UpdateMapEntry(dockerID string, args map[string]string) error {

	serverResp, err := cli.R().SetBody(args).Post("/programmap/update/" + dockerID)
	if err != nil {
		return fmt.Errorf("error while connecting to daemon: %s", err)
	}

	if serverResp.StatusCode() != http.StatusOK &&
		serverResp.StatusCode() != http.StatusAccepted {
		return processErrorBody(serverResp.Body(), nil)
	}

	return nil
}

func (cli Client) DeleteMapEntry(dockerID string, args map[string]string) error {

	serverResp, err := cli.R().SetBody(args).Delete("/programmap/" + dockerID)
	if err != nil {
		return fmt.Errorf("error while connecting to daemon: %s", err)
	}

	if serverResp.StatusCode() != http.StatusOK &&
		serverResp.StatusCode() != http.StatusAccepted {
		return processErrorBody(serverResp.Body(), nil)
	}

	return nil
}

func (cli Client) DumpMap2String(dockerID, progType, mapID string) (string, error) {

	serverResp, err := cli.R().Get("/programmap-dump/" + dockerID + "/" + progType + "/" + mapID)
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

	return string(serverResp.Body()), nil
}
