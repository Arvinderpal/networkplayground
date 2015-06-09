package main

import (
	"github.com/codegangsta/cli"
	"os"
)

func init() {
	// daemon.Initialize()
}

func main() {

	app := cli.NewApp()
	app.Name = "network manager"
	app.Usage = "virtual network for jobs"
	app.Version = "0.1.0"
	app.Flags = []cli.Flag{
		cli.StringFlag{
			Name:  "configfile",
			Value: "/etc/network/network_manager.config",
			Usage: "Name of the configuration file",
		},
	}
	app.Action = Run
	app.Run(os.Args)
}

func Run(ctx *cli.Context) {
	println("Using configuration file: ", ctx.String("configfile"))
	// configFilename := ctx.String(config.CFG_FILE)
	// err := config.Parse(configFilename)
	// if err != nil {
	// 	log.Fatal("Unable to parse configuration file " + configFilename)
	// 	os.Exit(1)
	// }
	// d := daemon.NewDaemon()
	// d.Run(ctx)
	println("...Run() done.")
}
