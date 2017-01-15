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
	"io"
	"strconv"
	"sync"
	"time"

	// "github.com/networkplayground/common"
	// "github.com/cilium/cilium/common/addressing"
	// "github.com/cilium/cilium/common/ipam"
	// "github.com/cilium/cilium/common/types"
	// "github.com/cilium/cilium/pkg/endpoint"
	// "github.com/cilium/cilium/pkg/labels"

	// dClient "github.com/docker/engine-api/client" -- DEPRECATED
	dTypes "github.com/docker/docker/api/types"
	dTypesEvents "github.com/docker/docker/api/types/events"
	// dClient "github.com/docker/docker/client"
	// dTypes "github.com/docker/engine-api/types" -- DEPRECATED
	// dTypesEvents "github.com/docker/engine-api/types/events" -- DEPRECATED

	ctx "golang.org/x/net/context"
	// k8sDockerLbls "k8s.io/client-go/1.5/pkg/kubelet/types"
)

const (
	syncRateDocker = time.Duration(30 * time.Second)

	maxRetries = 3
)

// EnableDockerEventListener watches for docker events. Performs the plumbing for the
// containers started or dead.
func (d *Daemon) EnableDockerEventListener() error {
	log.Infof("Starting docker event listener")
	eo := dTypes.EventsOptions{Since: strconv.FormatInt(time.Now().Unix(), 10)}
	messages, errs := d.dockerClient.Events(ctx.Background(), eo)

	d.EnableDockerSync(true)
	go d.listenForEvents(messages, errs)
	log.Infof("Listening for docker events")

	return nil
}

func (d *Daemon) EnableDockerSync(once bool) {
	var wg sync.WaitGroup
	for {
		cList, err := d.dockerClient.ContainerList(ctx.Background(), dTypes.ContainerListOptions{All: false})
		if err != nil {
			log.Errorf("Failed to retrieve the container list %s", err)
		}
		for _, cont := range cList {
			wg.Add(1)
			go func(wg *sync.WaitGroup, id string) {
				d.createContainer(id)
				wg.Done()
			}(&wg, cont.ID)
		}

		if once {
			return
		}
		wg.Wait()
		time.Sleep(syncRateDocker)
	}
}

func (d *Daemon) listenForEvents(messages <-chan dTypesEvents.Message, errs <-chan error) {

	for {
		select {
		case err := <-errs:
			if err != nil && err != io.EOF {
				log.Errorf("Received an err from Docker client: %v", err)

			}
			if err == io.EOF {
				// awander: should we just exit the go routine here...
				log.Info("Recieved EOF from Docker client...exiting")
				break
			}
		case e := <-messages:
			log.Infof("Processing an event %+v", e)
			go d.processEvent(e)
		}
	}
}

func (d *Daemon) processEvent(m dTypesEvents.Message) {
	if m.Type == "container" {
		switch m.Status {
		case "start":
			d.createContainer(m.ID)
		case "die":
			d.deleteContainer(m.ID)
		}
	}
}

func (d *Daemon) createContainer(dockerID string) {
	log.Debugf("Processing create event for docker container %s", dockerID)

	// d.containersMU.Lock()
	// if isNewContainer, container, err := d.updateProbeLabels(dockerID); err != nil {
	// 	d.containersMU.Unlock()
	// 	log.Errorf("%s", err)
	// } else {
	// 	d.containersMU.Unlock()
	// 	if err := d.updateContainer(container, isNewContainer); err != nil {
	// 		log.Errorf("%s", err)
	// 	}
	// }
}

func (d *Daemon) deleteContainer(dockerID string) {
	log.Debugf("Processing deletion event for docker container %s", dockerID)

	// d.containersMU.Lock()
	// if container, ok := d.containers[dockerID]; ok {
	// 	ep, err := d.EndpointGetByDockerID(dockerID)
	// 	if err != nil {
	// 		log.Warningf("Error while getting endpoint by docker ID: %s", err)
	// 	}

	// 	sha256sum, err := container.OpLabels.EndpointLabels.SHA256Sum()
	// 	if err != nil {
	// 		log.Errorf("Error while creating SHA256Sum for labels %+v: %s", container.OpLabels.EndpointLabels, err)
	// 	}

	// 	if err := d.DeleteLabelsBySHA256(sha256sum, dockerID); err != nil {
	// 		log.Errorf("Error while deleting labels (SHA256SUM:%s) %+v: %s", sha256sum, container.OpLabels.EndpointLabels, err)
	// 	}

	// 	delete(d.containers, dockerID)

	// 	if ep != nil {
	// 		d.EndpointLeave(ep.ID)
	// 		var ipamType ipam.IPAMType
	// 		if ep.IsCNI() {
	// 			ipamType = ipam.CNIIPAMType
	// 		} else {
	// 			ipamType = ipam.LibnetworkIPAMType
	// 		}

	// 		if d.conf.IPv4Enabled {
	// 			ipv4 := ep.IPv4.IP()
	// 			if err := d.ReleaseIP(ipamType, ipam.IPAMReq{IP: &ipv4}); err != nil {
	// 				log.Warningf("error while releasing IPv4 %s: %s", ep.IPv4.IP(), err)
	// 			}
	// 		}
	// 		ipv6 := ep.IPv6.IP()
	// 		if err := d.ReleaseIP(ipamType, ipam.IPAMReq{IP: &ipv6}); err != nil {
	// 			log.Warningf("error while releasing IPv6 %s: %s", ep.IPv6.IP(), err)
	// 		}
	// 	}
	// }
	// d.containersMU.Unlock()
}
