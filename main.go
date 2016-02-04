package main

import (
	"github.com/codegangsta/cli"
	"github.com/davecheney/profile"
	"os"
)

func init() {
	// daemon.Initialize()
}

func main() {
	defer profile.Start(profile.CPUProfile).Stop()

	app := cli.NewApp()
	app.Name = "simple ovs driver"
	app.Usage = "ovs driver used an create bridge and attach netns to the bridge"
	app.Version = "0.1.0"
	app.Flags = []cli.Flag{
		cli.StringFlag{
			Name:  "configfile",
			Value: "/etc/network/simple_ovs_driver.config",
			Usage: "Name of the configuration file",
		},
	}
	app.Action = Run
	app.Run(os.Args)
}

func Run(ctx *cli.Context) {
	println("Using configuration file: ", ctx.String("configfile"))
	configFilename := ctx.String(config.CFG_FILE)
	err := config.Parse(configFilename)
	if err != nil {
		log.Fatal("Unable to parse configuration file " + configFilename)
		os.Exit(1)
	}
	// d := daemon.NewDaemon()
	// d.Run(ctx)
	println("...Run() done.")
}
