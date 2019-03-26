package main

import (
	"crypto/md5"
	"crypto/sha1"
	"crypto/sha256"
	"fmt"
	"hash"
	"io"
	"os"
	"strings"

	v "github.com/hashicorp/go-version"
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

func VersionString() string {
	return version()
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

var localPorts = map[string]int{
	"cloudbreak": 9091,
	"periscope":  8085,
	"datalake":   8086,
}

func ServiceURL(args []string) {
	serviceName, bridgeAddress, localDevList := unpackServiceURLArgs(args)
	if strings.Contains(localDevList, serviceName) {
		fmt.Printf("http://%s:%v", bridgeAddress, localPorts[serviceName])
	} else {
		fmt.Printf("http://%s:8080", serviceName)
	}
}

func unpackServiceURLArgs(args []string) (string, string, string) {
	return args[0], args[1], args[2]
}
