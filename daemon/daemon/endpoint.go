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

import "github.com/networkplayground/pkg/endpoint"

// Returns a pointer of a copy endpoint if the endpoint was found, nil
// otherwise. It also updates the daemon map with IDs by which the endpoint
// can be retreived.
func (d *Daemon) getEndpointAndUpdateIDs(dockerID, dockerEPID string) *endpoint.Endpoint {
	var (
		ep *endpoint.Endpoint
		ok bool
	)

	setIfNotEmpty := func(receiver *string, provider string) {
		if receiver != nil && *receiver == "" && provider != "" {
			*receiver = provider
		}
	}

	d.endpointsMU.Lock()
	defer d.endpointsMU.Unlock()

	if dockerID != "" {
		ep, ok = d.endpointsDocker[dockerID]
	} else if dockerEPID != "" {
		ep, ok = d.endpointsDockerEP[dockerEPID]
	} else {
		return nil
	}

	if ok {
		setIfNotEmpty(&ep.DockerID, dockerID)
		setIfNotEmpty(&ep.DockerEndpointID, dockerEPID)

		// Update all IDs in respective MAPs
		d.insertEndpoint(ep)
		return ep.DeepCopy()
	}

	return nil
}

// Public API to insert an endpoint without connecting it to a container
func (d *Daemon) InsertEndpoint(ep *endpoint.Endpoint) {
	d.endpointsMU.Lock()
	d.insertEndpoint(ep)
	d.endpointsMU.Unlock()
}

// insertEndpoint inserts the ep in the endpoints map. To be used with endpointsMU locked.
func (d *Daemon) insertEndpoint(ep *endpoint.Endpoint) {
	if ep.Status == nil {
		ep.Status = &endpoint.EndpointStatus{}
	}

	// d.endpoints[ep.ID] = ep

	if ep.DockerID != "" {
		d.endpointsDocker[ep.DockerID] = ep
	}

	if ep.DockerEndpointID != "" {
		d.endpointsDockerEP[ep.DockerEndpointID] = ep
	}
}
