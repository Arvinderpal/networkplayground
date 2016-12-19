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
	"net/http"
)

type route struct {
	Name        string
	Method      string
	Pattern     string
	HandlerFunc http.HandlerFunc
}

type routes []route

func (r *Router) initBackendRoutes() {
	r.routes = routes{
		route{
			"Ping", "GET", "/ping", r.ping,
		},
		route{
			"GlobalStatus", "GET", "/healthz", r.globalStatus,
		},
		route{
			"Update", "POST", "/update", r.update,
		},
		route{
			"G1MapInsert", "POST", "/g1mapinsert", r.g1MapInsert,
		},
		route{
			"G2MapUpdate", "POST", "/g2map", r.g2MapUpdate,
		},
		route{
			"G3MapUpdate", "POST", "/g3map", r.g3MapUpdate,
		},
		route{
			"G3MapDump", "GET", "/g3maps", r.g3MapDump,
		},
		route{
			"G3MapDel", "DELETE", "/g3map/{ip}", r.g3MapDel,
		},
	}
}
