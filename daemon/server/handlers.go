//
// Copyright 2016 Authors of Cilium
//
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
package server

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"

	"github.com/networkplayground/pkg/endpoint"
	"github.com/networkplayground/pkg/option"

	"github.com/gorilla/mux"
)

func (router *Router) ping(w http.ResponseWriter, r *http.Request) {
	if resp, err := router.daemon.Ping(); err != nil {
		processServerError(w, r, err)
	} else {
		w.WriteHeader(http.StatusOK)
		if err := json.NewEncoder(w).Encode(resp); err != nil {
			processServerError(w, r, err)
		}
	}
}

func (router *Router) globalStatus(w http.ResponseWriter, r *http.Request) {
	if resp, err := router.daemon.GlobalStatus(); err != nil {
		processServerError(w, r, err)
	} else {
		w.WriteHeader(http.StatusOK)
		if err := json.NewEncoder(w).Encode(resp); err != nil {
			processServerError(w, r, err)
		}
	}
}

func (router *Router) update(w http.ResponseWriter, r *http.Request) {
	var opts option.OptionMap
	if err := json.NewDecoder(r.Body).Decode(&opts); err != nil {
		processServerError(w, r, err)
		return
	}
	if err := router.daemon.Update(opts); err != nil {
		processServerError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusAccepted)
}

func (router *Router) g1MapInsert(w http.ResponseWriter, r *http.Request) {
	var opts map[string]string
	if err := json.NewDecoder(r.Body).Decode(&opts); err != nil {
		processServerError(w, r, err)
		return
	}
	if err := router.daemon.G1MapInsert(opts); err != nil {
		processServerError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusAccepted)
}

func (router *Router) g2MapUpdate(w http.ResponseWriter, r *http.Request) {
	var opts map[string]string
	if err := json.NewDecoder(r.Body).Decode(&opts); err != nil {
		processServerError(w, r, err)
		return
	}
	if err := router.daemon.G2MapUpdate(opts); err != nil {
		processServerError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusAccepted)
}

func (router *Router) g3MapUpdate(w http.ResponseWriter, r *http.Request) {
	var opts map[string]string
	if err := json.NewDecoder(r.Body).Decode(&opts); err != nil {
		processServerError(w, r, err)
		return
	}
	if err := router.daemon.G3MapUpdate(opts); err != nil {
		processServerError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusAccepted)
}

func (router *Router) g3MapDel(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	ip, exists := vars["ip"]
	if !exists {
		processServerError(w, r, errors.New("server received delete without ip/key"))
		return
	}

	if err := router.daemon.G3MapDelete(ip); err != nil {
		processServerError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (router *Router) g3MapDump(w http.ResponseWriter, r *http.Request) {
	dump, err := router.daemon.G3MapDump()
	if err != nil {
		processServerError(w, r, err)
		return
	}
	if dump == "" {
		w.WriteHeader(http.StatusNoContent)
		return
	}
	w.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(w).Encode(dump); err != nil {
		processServerError(w, r, err)
		return
	}
}

func (router *Router) endpointCreate(w http.ResponseWriter, r *http.Request) {

	d := json.NewDecoder(r.Body)
	var ep endpoint.Endpoint
	if err := d.Decode(&ep); err != nil {
		processServerError(w, r, err)
		return
	}
	logger.Debugf("endpointCreate: %d", ep.DockerID)
	if err := router.daemon.EndpointJoin(ep); err != nil {
		processServerError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusCreated)
}

func (router *Router) endpointDelete(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	dockerID, exists := vars["dockerID"]
	if !exists {
		processServerError(w, r, errors.New("server received empty docker id"))
		return
	}
	logger.Debugf("endpointDelete: %d", dockerID)
	// if err := router.daemon.EndpointLeave(dockerID); err != nil {
	// 	processServerError(w, r, err)
	// 	return
	// }
	w.WriteHeader(http.StatusNoContent)
}

func (router *Router) endpointGet(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	dockerID, exists := vars["dockerID"]
	if !exists {
		processServerError(w, r, errors.New("server received empty docker ID"))
		return
	}
	logger.Debugf("endpointGet: %d", dockerID)
	ep, err := router.daemon.EndpointGet(dockerID)
	if err != nil {
		processServerError(w, r, fmt.Errorf("error while getting endpoint: %s", err))
		return
	}
	if ep == nil {
		w.WriteHeader(http.StatusNoContent)
		return
	}
	w.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(w).Encode(ep); err != nil {
		processServerError(w, r, err)
		return
	}
}

func (router *Router) endpointUpdate(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	dockerID, exists := vars["dockerID"]
	if !exists {
		processServerError(w, r, errors.New("server received empty docker id"))
		return
	}
	logger.Debugf("endpointUpdate: %d", dockerID)
	// var opts option.OptionMap
	// if err := json.NewDecoder(r.Body).Decode(&opts); err != nil {
	// 	processServerError(w, r, err)
	// 	return
	// }
	// if err := router.daemon.EndpointUpdate(dockerID, opts); err != nil {
	// 	processServerError(w, r, err)
	// 	return
	// }
	w.WriteHeader(http.StatusAccepted)
}

func (router *Router) endpointSave(w http.ResponseWriter, r *http.Request) {
	var ep endpoint.Endpoint
	if err := json.NewDecoder(r.Body).Decode(&ep); err != nil {
		processServerError(w, r, err)
		return
	}
	logger.Debugf("endpointSave: %d", ep.DockerID)
	if err := router.daemon.EndpointSave(ep); err != nil {
		processServerError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusCreated)
}

func (router *Router) endpointLeaveByDockerEPID(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	dockerEPID, exists := vars["dockerEPID"]
	if !exists {
		processServerError(w, r, errors.New("server received empty docker endpoint id"))
		return
	}
	logger.Debugf("endpointLeaveByDockerEPID: %d", dockerEPID)
	if err := router.daemon.EndpointLeaveByDockerEPID(dockerEPID); err != nil {
		processServerError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (router *Router) endpointGetByDockerEPID(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	dockerEPID, exists := vars["dockerEPID"]
	if !exists {
		processServerError(w, r, errors.New("server received empty docker endpoint id"))
		return
	}
	ep, err := router.daemon.EndpointGetByDockerEPID(dockerEPID)
	if err != nil {
		processServerError(w, r, fmt.Errorf("error while getting endpoint: %s", err))
		return
	}
	if ep == nil {
		w.WriteHeader(http.StatusNoContent)
		return
	}
	w.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(w).Encode(ep); err != nil {
		processServerError(w, r, err)
		return
	}
}

func (router *Router) endpointsGet(w http.ResponseWriter, r *http.Request) {
	eps, err := router.daemon.EndpointsGet()
	if err != nil {
		processServerError(w, r, fmt.Errorf("error while getting endpoints: %s", err))
		return
	}
	if eps == nil {
		w.WriteHeader(http.StatusNoContent)
		return
	}
	w.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(w).Encode(eps); err != nil {
		processServerError(w, r, err)
		return
	}
}
