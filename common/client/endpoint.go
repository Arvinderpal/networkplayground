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
	"encoding/json"
	"fmt"
	"net/http"

	"github.com/networkplayground/pkg/endpoint"
	"github.com/networkplayground/pkg/option"
)

// EndpointJoin sends a endpoint POST request with ep to the daemon.
func (cli Client) EndpointJoin(ep endpoint.Endpoint) error {

	logger.Debugf("POST /endpoint/%d", ep.DockerID)

	serverResp, err := cli.R().SetBody(ep).Post("/endpoint/" + ep.DockerID)
	if err != nil {
		return fmt.Errorf("error while connecting to daemon: %s", err)
	}

	if serverResp.StatusCode() != http.StatusCreated {
		return processErrorBody(serverResp.Body(), ep)
	}

	return nil
}

// EndpointLeave sends a DELETE request with dockerID to the daemon.
func (cli Client) EndpointLeave(dockerID string) error {

	logger.Debugf("DELETE /endpoint/%d", dockerID)

	serverResp, err := cli.R().Delete("/endpoint/" + dockerID)
	if err != nil {
		return fmt.Errorf("error while connecting to daemon: %s", err)
	}

	if serverResp.StatusCode() != http.StatusNoContent &&
		serverResp.StatusCode() != http.StatusNotFound {
		return processErrorBody(serverResp.Body(), dockerID)
	}

	return nil
}

// EndpointGetByDockerID sends a GET request with dockerID to the daemon.
func (cli Client) EndpointGet(dockerID string) (*endpoint.Endpoint, error) {

	logger.Debugf("GET /endpoint/%d", dockerID)

	serverResp, err := cli.R().Get("/endpoint/" + dockerID)
	if err != nil {
		return nil, fmt.Errorf("error while connecting to daemon: %s", err)
	}

	if serverResp.StatusCode() != http.StatusOK &&
		serverResp.StatusCode() != http.StatusNoContent {
		return nil, processErrorBody(serverResp.Body(), dockerID)
	}

	if serverResp.StatusCode() == http.StatusNoContent {
		return nil, nil
	}

	var ep endpoint.Endpoint
	if err := json.Unmarshal(serverResp.Body(), &ep); err != nil {
		return nil, err
	}

	return &ep, nil
}

// EndpointLeaveByDockerEPID sends a DELETE request with dockerEPID to the daemon.
func (cli Client) EndpointLeaveByDockerEPID(dockerEPID string) error {

	logger.Debug("DELETE /endpoint-by-docker-ep-id/" + dockerEPID)

	serverResp, err := cli.R().Delete("/endpoint-by-docker-ep-id/" + dockerEPID)
	if err != nil {
		return fmt.Errorf("error while connecting to daemon: %s", err)
	}

	if serverResp.StatusCode() != http.StatusNoContent &&
		serverResp.StatusCode() != http.StatusNotFound {
		return processErrorBody(serverResp.Body(), dockerEPID)
	}

	return nil
}

// EndpointGetByDockerEPID sends a GET request with dockerEPID to the daemon.
func (cli Client) EndpointGetByDockerEPID(dockerEPID string) (*endpoint.Endpoint, error) {

	logger.Debugf("GET /endpoint/%s", dockerEPID)

	serverResp, err := cli.R().Get("/endpoint-by-docker-ep-id/" + dockerEPID)
	if err != nil {
		return nil, fmt.Errorf("error while connecting to daemon: %s", err)
	}

	if serverResp.StatusCode() != http.StatusOK &&
		serverResp.StatusCode() != http.StatusNoContent {
		return nil, processErrorBody(serverResp.Body(), dockerEPID)
	}

	if serverResp.StatusCode() == http.StatusNoContent {
		return nil, nil
	}

	var ep endpoint.Endpoint
	if err := json.Unmarshal(serverResp.Body(), &ep); err != nil {
		return nil, err
	}

	return &ep, nil
}

// EndpointsGet sends a GET request to the daemon.
func (cli Client) EndpointsGet() ([]endpoint.Endpoint, error) {

	serverResp, err := cli.R().Get("/endpoints")
	if err != nil {
		return nil, fmt.Errorf("error while connecting to daemon: %s", err)
	}

	if serverResp.StatusCode() != http.StatusOK &&
		serverResp.StatusCode() != http.StatusNoContent {
		return nil, processErrorBody(serverResp.Body(), nil)
	}

	if serverResp.StatusCode() == http.StatusNoContent {
		return nil, nil
	}

	var eps []endpoint.Endpoint
	if err := json.Unmarshal(serverResp.Body(), &eps); err != nil {
		return nil, err
	}

	return eps, nil
}

// EndpointUpdate sends a POST request with dockerID and opts to the daemon.
func (cli Client) EndpointUpdate(dockerID string, opts option.OptionMap) error {

	logger.Debugf("Update: POST /endpoint/%d", dockerID)

	serverResp, err := cli.R().SetBody(opts).Post("/endpoint/update/" + dockerID)
	if err != nil {
		return fmt.Errorf("error while connecting to daemon: %s", err)
	}

	if serverResp.StatusCode() != http.StatusOK &&
		serverResp.StatusCode() != http.StatusAccepted {
		return processErrorBody(serverResp.Body(), dockerID)
	}

	return nil
}

// EndpointSave sends a endpoint POST request with ep to the daemon.
func (cli Client) EndpointSaveByDockerEPID(ep endpoint.Endpoint) error {

	logger.Debugf("POST /endpoint/save/%s", ep.DockerEndpointID)

	serverResp, err := cli.R().SetBody(ep).Post("/endpoint/save/" + ep.DockerEndpointID)
	if err != nil {
		return fmt.Errorf("error while connecting to daemon: %s", err)
	}

	if serverResp.StatusCode() != http.StatusCreated {
		return processErrorBody(serverResp.Body(), ep)
	}

	return nil
}
