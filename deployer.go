package main

import (
	"crypto/md5"
	"crypto/sha1"
	"crypto/sha256"
	"fmt"
	"hash"
	"io"
	"log"
	"os"
	"runtime"
	"strings"

	v "github.com/hashicorp/go-version"
	"github.com/progrium/go-basher"
	"github.com/skratchdot/open-golang/open"
)

var Version string
var GitRevision string

func version() (v string) {
	if GitRevision == "" {
		v = Version
	} else {
		v = fmt.Sprintf("%s-%s", Version, GitRevision)
	}
	return
}

func fatal(msg string) {
	println("!!", msg)
	os.Exit(2)
}

func BinVersion(args []string) {
	fmt.Println(version())
}

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

func OpenBrowser(args []string) {
	err := open.Start(args[0])
	if err != nil {
		fatal("Can't open browser: '" + err.Error())
	}
}

func VersionCompare(args []string) {
	v0, err := v.NewVersion(args[0])
	if err != nil {
		fatal("Can't parse version string" + err.Error())
	}

	v1, err := v.NewVersion(args[1])
	if err != nil {
		fatal("Can't parse version string" + err.Error())
	}
	fmt.Println(v0.Compare(v1))
}

func Checksum(args []string) {
	if len(args) < 1 {
		fatal("No algorithm specified")
	}
	var h hash.Hash
	switch args[0] {
	case "md5":
		h = md5.New()
	case "sha1":
		h = sha1.New()
	case "sha256":
		h = sha256.New()
	default:
		fatal("Algorithm '" + args[0] + "' is unsupported")
	}
	io.Copy(h, os.Stdin)
	fmt.Printf("%x\n", h.Sum(nil))
}

func main() {
	if len(os.Args) == 2 && os.Args[1] == "--version" {
		fmt.Println("Cloudbreak Deployer:", version())
		os.Exit(0)
	}

	application(map[string]func([]string){
		"checksum":        Checksum,
		"bin-version":     BinVersion,
		"browse":          OpenBrowser,
		"version-compare": VersionCompare,
	}, []string{
		"include/aws-roles.bash",
		"include/azure-tools.bash",
		"include/circle.bash",
		"include/cloudbreak.bash",
		"include/compose.bash",
		"include/cmd.bash",
		"include/color.bash",
		"include/deployer.bash",
		"include/deps.bash",
		"include/db.bash",
		"include/docker.bash",
		"include/env.bash",
		"include/fn.bash",
		"include/migrate.bash",
		"include/machine.bash",
		"include/module.bash",
	}, Asset, false)

}
