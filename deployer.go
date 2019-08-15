package main

import (
	"fmt"
	"log"
	"os"
	"runtime"
	"strings"

	"github.com/progrium/go-basher"
)

// Copied from https://github.com/progrium/go-basher/blob/master/basher.go#L37
// to be able to add exporting DEBUG and TRACE, as we don't inherit anything
// from parent bash

func application(
	funcs map[string]func([]string),
	scripts []string,
	loader func(string) ([]byte, error),
	copyEnv bool) {

	bashPath := ".deps/bin/bash-" + runtime.GOOS
	RestoreAsset(".", bashPath)
	bash, err := basher.NewContext(bashPath, os.Getenv("DEBUG") != "")

	bash.Export("PATH", os.Getenv("PATH"))
	bash.Export("DEBUG", os.Getenv("DEBUG"))
	bash.Export("TRACE", os.Getenv("TRACE"))
	bash.Export("HOME", os.Getenv("HOME"))
	bash.Export("CBD_DEFAULT_PROFILE", os.Getenv("CBD_DEFAULT_PROFILE"))
	for _, e := range os.Environ() {
		if strings.HasPrefix(e, "DOCKER_") {
			v := strings.Split(e, "=")
			bash.Export(v[0], v[1])
		}
	}

	if err != nil {
		log.Fatal(err)
	}
	for name, fn := range funcs {
		bash.ExportFunc(name, fn)
	}
	if bash.HandleFuncs(os.Args) {
		os.Exit(0)
	}

	for _, script := range scripts {
		bash.Source(script, loader)
	}
	if copyEnv {
		bash.CopyEnv()
	}
	status, err := bash.Run("main", os.Args[1:])
	if err != nil {
		log.Fatal(err)
	}
	os.Exit(status)
}

func main() {
	if len(os.Args) == 2 && os.Args[1] == "--version" {
		fmt.Println("Cloudbreak Deployer:", version())
		os.Exit(0)
	}

	application(map[string]func([]string){
		"checksum":              Checksum,
		"bin-version":           BinVersion,
		"browse":                OpenBrowser,
		"version-compare":       VersionCompare,
		"generate-compose-yaml": GenerateComposeYaml,
		"service-url":           ServiceURL,
		"generate-traefik-toml": GenerateTraefikToml,
		"generate-caddy-file":   GenerateCaddyFile,
		"host-from-url":         HostFromURL,
		"port-from-url":         PortFromURL,
	}, []string{
		"include/circle.bash",
		"include/cloudbreak.bash",
		"include/cmd.bash",
		"include/color.bash",
		"include/compose.bash",
		"include/db.bash",
		"include/deployer.bash",
		"include/deps.bash",
		"include/docker.bash",
		"include/env.bash",
		"include/export.bash",
		"include/fn.bash",
		"include/migrate.bash",
		"include/module.bash",
		"include/utils.bash",
		"include/vault.bash",
	}, Asset, false)

}
