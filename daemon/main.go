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
	"net"
	"os"
	"os/exec"
	"strings"
	"text/tabwriter"

	common "github.com/networkplayground/common"
	rclient "github.com/networkplayground/common/client"
	"github.com/networkplayground/daemon/daemon"
	s "github.com/networkplayground/daemon/server"
	"github.com/networkplayground/pkg/option"

	"github.com/codegangsta/cli"
	"github.com/op/go-logging"
)

const (
	OptionDebug = "Debug"
)

// Programs cli argument indexes
// <id> <type> <start/stop/map> <dump/update/delete> <key=value>
const (
	DOCKER_ID_IDX       = 0
	PROGRAM_TYPE_IDX    = 1
	PROGRAM_OPS_IDX     = 2
	PROGRAM_MAP_OPS_IDX = 3
	PROGRAM_MAP_ID_IDX  = 4
	PROGRAM_MAP_KV_IDX  = 5
)

var (
	config = daemon.NewConfig()

	// Arguments variables keep in alphabetical order
	socketPath string
	nodeAddr   string

	log = logging.MustGetLogger("regulus-net-daemon")

	// CliCommand is the command that will be used in main program.
	CliCommand cli.Command
)

func init() {
	CliCommand = cli.Command{
		Name: "daemon",
		// Keep Destination alphabetical order
		Subcommands: []cli.Command{
			{
				Name:   "run",
				Usage:  "Run the daemon",
				Before: initEnv,
				Action: run,
				Flags: []cli.Flag{
					cli.StringFlag{
						Destination: &config.LibDir,
						Name:        "D",
						Value:       common.DefaultLibDir,
						Usage:       "library directory",
					},
					cli.StringFlag{
						Destination: &config.RunDir,
						Name:        "R",
						Value:       common.RegulusPath,
						Usage:       "Runtime data directory",
					},
					cli.StringFlag{
						Destination: &socketPath,
						Name:        "s",
						Value:       common.RegulusSock,
						Usage:       "Sets the socket path to listen for connections",
					},
					cli.StringFlag{
						Destination: &config.Device,
						Name:        "snoop-device, d",
						Value:       "eth1",
						Usage:       "Device to snoop on (default is eth1)",
					},
					cli.StringFlag{
						Destination: &config.DockerEndpoint,
						Name:        "e",
						Value:       "unix:///var/run/docker.sock",
						Usage:       "Register a listener for docker events on the given endpoint",
					},
					cli.StringFlag{
						Destination: &nodeAddr,
						Name:        "n, node-address",
						Value:       "",
						Usage:       "IPv4 address of node, must be in correct format",
					},
					cli.StringFlag{
						Destination: &config.K8sEndpoint,
						Name:        "k8s-api-server, k",
						Usage:       "Kubernetes api address server",
					},
					cli.StringFlag{
						Destination: &config.K8sCfgPath,
						Name:        "k8s-kubeconfig-path",
						Usage:       "Absolute path to the kubeconfig file",
					},
					cli.BoolFlag{
						Name:  "debug",
						Usage: "Enable debug messages",
					},
				},
			},
			{
				Name:      "config",
				Usage:     "Manage daemon configuration",
				Action:    configDaemon,
				ArgsUsage: "[<option>=(enable|disable) ...]",
			},
			{
				Name:   "status",
				Usage:  "Returns the daemon current status",
				Action: statusDaemon,
			},
			{
				Name:      "g1map",
				Usage:     "Insert entries in G1Map",
				Action:    g1mapUpdate,
				ArgsUsage: "[<key>=(value) ...]",
			},
			{
				Name:      "g2map",
				Usage:     "List, Update entries in G2Map",
				Action:    g2mapUpdate,
				ArgsUsage: "[<list>, <update><ipv4>=insert/delete ...]",
			},
			{
				Name:      "g3map",
				Usage:     "List, Update, Delete entries in G3Map",
				Action:    g3mapUpdate,
				ArgsUsage: "[<list>, <update><ipv4>=<init count>..., <delete><ipv4>...]",
			},
			{
				Name:      "program",
				Usage:     "Start and Stop Programs and List, Update, Delete entries in Program Maps",
				Action:    programUpdate,
				ArgsUsage: "<docker container id> <program name> <start/stop/map> <map operation> <map args>",
			},
		},
	}
}

func statusDaemon(ctx *cli.Context) {
	var (
		client *rclient.Client
		err    error
	)
	if host := ctx.GlobalString("host"); host == "" {
		client, err = rclient.NewDefaultClient()
	} else {
		client, err = rclient.NewClient(host, nil)
	}
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error while creating client: %s\n", err)
		os.Exit(1)
	}

	if sr, err := client.GlobalStatus(); err != nil {
		fmt.Fprintf(os.Stderr, "Status: ERROR - Unable to reach out daemon: %s\n", err)
		os.Exit(1)
	} else {
		w := tabwriter.NewWriter(os.Stdout, 2, 0, 3, ' ', 0)
		fmt.Fprintf(w, "Status:\t%s\n", sr)
		w.Flush()

		os.Exit(0)
	}

}

func configDaemon(ctx *cli.Context) {
	var (
		client *rclient.Client
		err    error
	)

	first := ctx.Args().First()

	if first == "list" {
		for k, s := range daemon.DaemonOptionLibrary {
			fmt.Printf("%-24s %s\n", k, s.Description)
		}
		return
	}

	if host := ctx.GlobalString("host"); host == "" {
		client, err = rclient.NewDefaultClient()
	} else {
		client, err = rclient.NewClient(host, nil)
	}

	if err != nil {
		fmt.Fprintf(os.Stderr, "Error while creating regulus-client: %s\n", err)
		os.Exit(1)
	}

	res, err := client.Ping()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Unable to reach daemon: %s\n", err)
		os.Exit(1)
	}

	if res == nil {
		fmt.Fprintf(os.Stderr, "Empty response from daemon\n")
		os.Exit(1)
	}

	opts := ctx.Args()

	if len(opts) == 0 {
		res.Opts.Dump()
		return
	}

	dOpts := make(option.OptionMap, len(opts))

	for k := range opts {
		name, value, err := option.ParseOption(opts[k], &daemon.DaemonOptionLibrary)
		if err != nil {
			fmt.Printf("%s\n", err)
			os.Exit(1)
		}

		dOpts[name] = value

		err = client.Update(dOpts)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Unable to update daemon: %s\n", err)
			os.Exit(1)
		}
	}
}

func g1mapUpdate(ctx *cli.Context) {
	var (
		client *rclient.Client
		err    error
	)

	first := ctx.Args().First()

	if first == "list" {
		// TODO(awander): add method to get all G1Map entries
		// for k, s := range daemon.DaemonOptionLibrary {
		// 	fmt.Printf("%-24s %s\n", k, s.Description)
		// }
		return
	}

	if host := ctx.GlobalString("host"); host == "" {
		client, err = rclient.NewDefaultClient()
	} else {
		client, err = rclient.NewClient(host, nil)
	}

	if err != nil {
		fmt.Fprintf(os.Stderr, "Error while creating regulus-client: %s\n", err)
		os.Exit(1)
	}

	opts := ctx.Args()

	if len(opts) == 0 {
		return
	}

	dOpts := make(map[string]string, len(opts))

	for k := range opts {
		name, value, err := ParseArgsG1Map(opts[k])
		if err != nil {
			fmt.Printf("%s\n", err)
			os.Exit(1)
		}

		dOpts[name] = value

		err = client.G1MapInsert(dOpts)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Unable to update daemon: %s\n", err)
			os.Exit(1)
		}
	}
}

func g2mapUpdate(ctx *cli.Context) {
	var (
		client *rclient.Client
		err    error
	)

	if host := ctx.GlobalString("host"); host == "" {
		client, err = rclient.NewDefaultClient()
	} else {
		client, err = rclient.NewClient(host, nil)
	}

	if err != nil {
		fmt.Fprintf(os.Stderr, "Error while creating regulus-client: %s\n", err)
		os.Exit(1)
	}

	first := ctx.Args().First()
	if first == "list" {
		// if err := dumpG2Map(client); err != nil {
		// 	fmt.Errorf("Could not list G2Map: %s", err)
		// 	os.Exit(1)
		// }
		os.Exit(0)
	} else if first == "update" {
		// continue
	} else {
		fmt.Fprintf(os.Stderr, "%s is not a valid command\n", first)
		os.Exit(1)
	}

	opts := ctx.Args()

	if len(opts) == 0 {
		return
	}

	dOpts := make(map[string]string, len(opts))

	for k := range opts {
		name, value, err := ParseArgsG2Map(opts[k])
		if err != nil {
			fmt.Printf("%s\n", err)
			os.Exit(1)
		}

		dOpts[name] = value

		err = client.G2MapUpdate(dOpts)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Unable to update daemon: %s\n", err)
			os.Exit(1)
		}
	}
}

func g3mapUpdate(ctx *cli.Context) {
	var (
		client *rclient.Client
		err    error
	)

	if host := ctx.GlobalString("host"); host == "" {
		client, err = rclient.NewDefaultClient()
	} else {
		client, err = rclient.NewClient(host, nil)
	}

	if err != nil {
		fmt.Fprintf(os.Stderr, "Error while creating regulus-client: %s\n", err)
		os.Exit(1)
	}

	opts := ctx.Args()
	if len(opts) == 0 {
		return
	}
	first := ctx.Args().First()
	if first == "list" {
		dump, err := client.G3MapDump()
		if err != nil {
			fmt.Fprint(os.Stderr, "Could not retrieve G3Map: %s\n", err)
			os.Exit(1)
		}
		printDump(dump)
		os.Exit(0)
	} else if first == "update" {
		dOpts := make(map[string]string, len(opts))
		if len(opts) != 2 {
			fmt.Fprintf(os.Stderr, "Expected 2 options to g3map update but got: %s", len(opts))
			os.Exit(1)
		}
		name, value, err := daemon.ParseKVArgs(opts[1])
		if err != nil {
			fmt.Printf("%s\n", err)
			os.Exit(1)
		}

		dOpts[name] = value

		err = client.G3MapUpdate(dOpts)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Unable to update daemon: %s\n", err)
			os.Exit(1)
		}

	} else if first == "delete" {
		if len(opts) != 2 {
			fmt.Fprintf(os.Stderr, "Expected 2 options to g3map delete but got: %s", len(opts))
			os.Exit(1)
		}
		err = client.G3MapDelete(opts[1])
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error during delete: %s\n", err)
			os.Exit(1)
		}
	} else {
		fmt.Fprintf(os.Stderr, "%s is not a valid command\n", first)
		os.Exit(1)
	}
}

func printDump(dump string) {

	strs := strings.Split(dump, `\n`)
	for _, s := range strs {
		fmt.Println(s)
	}
}

func programUpdate(ctx *cli.Context) {
	var (
		client *rclient.Client
		err    error
	)

	if host := ctx.GlobalString("host"); host == "" {
		client, err = rclient.NewDefaultClient()
	} else {
		client, err = rclient.NewClient(host, nil)
	}

	if err != nil {
		fmt.Fprintf(os.Stderr, "Error while creating regulus-client: %s\n", err)
		os.Exit(1)
	}

	err = validateProgramCmdInputs(ctx)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Input validation failed: %s", err)
		os.Exit(1)
	}

	dockerID := ctx.Args().Get(DOCKER_ID_IDX)
	progType := ctx.Args().Get(PROGRAM_TYPE_IDX)
	operation := ctx.Args().Get(PROGRAM_OPS_IDX)

	dOpts := make(map[string]string, len(ctx.Args()))
	dOpts[common.PROGRAM_ARGS_TYPE_FIELD] = progType
	dOpts[common.PROGRAM_ARGS_OPERATION_FIELD] = operation

	switch strings.ToLower(operation) {
	case "start":
		err = client.StartProgram(dockerID, dOpts)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Unable to perform {%s} for program type {%s} on container {%s}: %s\n", operation, progType, dockerID, err)
			os.Exit(1)
		}
	case "stop":
		err = client.StopProgram(dockerID, dOpts)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Unable to perform {%s} for program type {%s} on container {%s}: %s\n", operation, progType, dockerID, err)
			os.Exit(1)
		}
	case "map":
		mapOperation := ctx.Args().Get(PROGRAM_MAP_OPS_IDX)
		mapID := ctx.Args().Get(PROGRAM_MAP_ID_IDX)
		dOpts[common.PROGRAM_ARGS_MAP_ID] = mapID
		switch mapOperation {
		case "dump":
			dump, err := client.DumpMap2String(dockerID, progType, mapID)
			if err != nil {
				fmt.Fprintf(os.Stderr, "Unable to perform {%s} {%s} for program type {%s} on container {%s}: %s \n", mapOperation, operation, progType, dockerID, err)
				os.Exit(1)
			}
			printDump(dump)
		case "update":
			// update can contain a single key value pair in the format: "key=value"
			dOpts[common.PROGRAM_ARGS_MAP_KV_PAIR] = ctx.Args().Get(PROGRAM_MAP_KV_IDX)
			if err := client.UpdateMapEntry(dockerID, dOpts); err != nil {
				fmt.Errorf("Could not list {%s}: %s", err)
				os.Exit(1)
			}
		case "delete":
			dOpts[common.PROGRAM_ARGS_MAP_KEY] = ctx.Args().Get(PROGRAM_MAP_KV_IDX)
			if err := client.DeleteMapEntry(dockerID, dOpts); err != nil {
				fmt.Errorf("Could not list {%s}: %s", err)
				os.Exit(1)
			}
		default:
			fmt.Fprintf(os.Stderr, "Unable to perform {%s} for program type {%s} on container {%s}: Unknown map operation {%s} \n", operation, progType, dockerID, mapOperation)
			os.Exit(1)
		}
	default:
		fmt.Fprintf(os.Stderr, "Unknown Operation %s", operation)
		os.Exit(1)
	}

}

func validateProgramCmdInputs(ctx *cli.Context) error {
	args := ctx.Args()
	if len(args) < 3 {
		return fmt.Errorf("Insufficient arguments provided\n")
	}
	operation := ctx.Args().Get(PROGRAM_OPS_IDX)
	if strings.ToLower(operation) == "map" {
		if len(args) < 4 {
			return fmt.Errorf("%s requires additional arguments\n", operation)
		}
		// <id> <type> map update key=value
		subOperation := ctx.Args().Get(PROGRAM_MAP_OPS_IDX)
		switch strings.ToLower(subOperation) {
		case "update":
			if len(args) < 6 {
				return fmt.Errorf("%s on %s requires mapID ('-' if N/A) and key=value pair be specified\n", subOperation, operation)
			}
			_, _, err := daemon.ParseKVArgs(ctx.Args().Get(PROGRAM_MAP_KV_IDX))
			if err != nil {
				return fmt.Errorf("%s on %s requires key and value pair in the format 'key=value'\n", subOperation, operation)
			}
		case "delete":
			if len(args) < 6 {
				return fmt.Errorf("%s on %s requires mapID ('-' if N/A) and key be specified\n", subOperation, operation)
			}
		case "dump":
			if len(args) < 5 {
				return fmt.Errorf("%s on %s requires mapID (use '-' if N/A) to be specified\n", subOperation, operation)
			}
		default:
			return fmt.Errorf("Unknown map operation %s", subOperation)
		}
	}
	return nil
}

func initEnv(ctx *cli.Context) error {
	config.OptsMU.Lock()
	if ctx.Bool("debug") {
		log.Info("Debuging is enabled")
		common.SetupLOG(log, "DEBUG")
		config.Opts.Set(OptionDebug, true)
	} else {
		common.SetupLOG(log, "INFO")
	}

	config.OptsMU.Unlock()

	ipaddr := net.ParseIP(nodeAddr)
	if ipaddr == nil {
		log.Fatalf("Unable to parse node address %s", nodeAddr)
	}
	config.NodeAddress = nodeAddr

	// Mount BPF Map directory if not already done
	args := []string{"-q", common.BPFMapRoot}
	_, err := exec.Command("mountpoint", args...).CombinedOutput()
	if err != nil {
		args = []string{"bpffs", common.BPFMapRoot, "-t", "bpf"}
		out, err := exec.Command("mount", args...).CombinedOutput()
		if err != nil {
			log.Fatalf("Command execution failed: %s\n%s", err, out)
		}
	}
	if config.IsK8sEnabled() && !strings.HasPrefix(config.K8sEndpoint, "http") {
		config.K8sEndpoint = "http://" + config.K8sEndpoint
	}

	return nil
}

func run(cli *cli.Context) {

	d, err := daemon.NewDaemon(config)
	if err != nil {
		log.Fatalf("Error while creating daemon: %s", err)
		return
	}

	// Register event listener in docker endpoint
	if err := d.EnableDockerEventListener(); err != nil {
		log.Warningf("Error while enabling docker event watcher %s", err)
	}
	go d.EnableDockerSync(false)

	server, err := s.NewServer(socketPath, d)
	if err != nil {
		log.Fatalf("Error while creating daemon: %s", err)
	}
	defer server.Stop()
	server.Start()
}
