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
	"os"
	"path/filepath"

	"github.com/networkplayground/pkg/endpoint"
	"github.com/networkplayground/pkg/option"
)

func (d *Daemon) lookupDockerEndpoint(dockerEPID string) *endpoint.Endpoint {
	if ep, ok := d.endpointsDockerEP[dockerEPID]; ok {
		return ep
	} else {
		return nil
	}
}

func (d *Daemon) lookupRegulusEndPoint(dockerID string) *endpoint.Endpoint {
	if ep, ok := d.endpointsDocker[dockerID]; ok {
		return ep
	} else {
		return nil
	}
}

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

// EndpointJoin sets up the endpoint working directory.
func (d *Daemon) EndpointJoin(ep endpoint.Endpoint) error {
	contDir := filepath.Join(".", ep.DockerID)

	if err := os.MkdirAll(contDir, 0777); err != nil {
		logger.Warningf("Failed to create container temporary directory: %s", err)
		return fmt.Errorf("failed to create temporary directory: %s", err)
	}

	d.conf.OptsMU.RLock()
	ep.SetDefaultOpts(d.conf.Opts)
	d.conf.OptsMU.RUnlock()

	d.InsertEndpoint(&ep)

	logger.Infof("Endpoint Join successful")
	return nil
}

// EndpointLeave cleans the directory used by the endpoint epID and all relevant details
// with the epID.
func (d *Daemon) EndpointLeave(dockerID string) error {
	d.endpointsMU.Lock()
	defer d.endpointsMU.Unlock()

	// TODO(awander): free resources and delete ep from map

	logger.Infof("Endpoint Leave successful on container: %s", dockerID)
	return nil
}

// EndpointGet returns a copy of the endpoint for the given endpointID, or nil if the
// endpoint was not found.
func (d *Daemon) EndpointGet(dockerID string) (*endpoint.Endpoint, error) {
	d.endpointsMU.RLock()
	defer d.endpointsMU.RUnlock()

	if ep := d.lookupRegulusEndPoint(dockerID); ep != nil {
		return ep.DeepCopy(), nil
	}

	return nil, nil
}

// EndpointLeaveByDockerEPID cleans the directory used by the endpoint dockerEPID and all
// relevant details with the epID.
func (d *Daemon) EndpointLeaveByDockerEPID(dockerEPID string) error {
	// FIXME: Validate dockerEPID?
	d.endpointsMU.Lock()
	if ep := d.lookupDockerEndpoint(dockerEPID); ep != nil {
		d.endpointsMU.Unlock()
		return d.EndpointLeave(ep.DockerID)
	} else {
		d.endpointsMU.Unlock()
		return fmt.Errorf("endpoint %s not found", dockerEPID)
	}
	logger.Infof("Endpoint Leave successful on Docker EPID: %s", dockerEPID)
	return nil
}

// EndpointGetByDockerEPID returns a copy of the endpoint for the given dockerEPID, or nil
// if the endpoint was not found.
func (d *Daemon) EndpointGetByDockerEPID(dockerEPID string) (*endpoint.Endpoint, error) {
	d.endpointsMU.RLock()
	defer d.endpointsMU.RUnlock()
	var ep *endpoint.Endpoint
	if ep = d.lookupDockerEndpoint(dockerEPID); ep != nil {
		return ep.DeepCopy(), nil
	}
	return nil, nil
}

// EndpointUpdate updates the given endpoint and recompiles the bpf map.
func (d *Daemon) EndpointUpdate(dockerID string, opts option.OptionMap) error {
	d.endpointsMU.Lock()
	defer d.endpointsMU.Unlock()

	// if ep := d.lookupCiliumEndpoint(epID); ep != nil {
	// 	if err := ep.Opts.Validate(opts); err != nil {
	// 		return err
	// 	}

	// 	if opts != nil && !ep.ApplyOpts(opts) {
	// 		// No changes have been applied, skip update
	// 		return nil
	// 	}

	// 	if val, ok := opts[endpoint.OptionLearnTraffic]; ok {
	// 		ll := labels.NewLearningLabel(ep.ID, val)
	// 		d.endpointsLearningRegister <- *ll
	// 	}

	// 	err := d.regenerateEndpoint(ep)
	// 	if err != nil {
	// 		ep.LogStatus(endpoint.Failure, err.Error())
	// 	} else {
	// 		ep.LogStatusOK("Successfully regenerated endpoint")
	// 	}
	// 	return err
	// } else {
	// 	return fmt.Errorf("endpoint %d not found", epID)
	// }
	return nil
}

// EndpointSave saves the endpoint in the daemon internal endpoint map.
func (d *Daemon) EndpointSave(ep endpoint.Endpoint) error {
	logger.Debugf("Endpoint Save: %v", ep)
	d.InsertEndpoint(&ep)
	return nil
}

// EndpointsGet returns a copy of all the endpoints or nil if there are no endpoints.
func (d *Daemon) EndpointsGet() ([]endpoint.Endpoint, error) {
	d.endpointsMU.RLock()
	defer d.endpointsMU.RUnlock()

	eps := []endpoint.Endpoint{}
	epsSet := map[*endpoint.Endpoint]bool{}
	for _, v := range d.endpointsDocker {
		epsSet[v] = true
	}
	if len(epsSet) == 0 {
		return nil, nil
	}
	for k := range epsSet {
		epCopy := k.DeepCopy()
		eps = append(eps, *epCopy)
	}
	return eps, nil
}
