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
	"net/http"

	"github.com/networkplayground/pkg/option"
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
