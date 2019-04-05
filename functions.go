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
	"text/template"

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

func ServiceURL(args []string) {
	serviceName, bridgeAddress, localDevList, protocol, localDevPort, servicePort := unpackServiceURLArgs(args)
	if strings.Contains(localDevList, serviceName) {
		printServiceUrl(bridgeAddress, protocol, localDevPort)
	} else {
		printServiceUrl(serviceName, protocol, servicePort)
	}
}

func printServiceUrl(serviceName string, protocol string, port string) {
	if len(port) > 0 {
		fmt.Printf("%s%s:%s", protocol, serviceName, port)
	} else {
		fmt.Printf("%s%s", protocol, serviceName)
	}
}

func unpackServiceURLArgs(args []string) (string, string, string, string, string, string) {
	return args[0], args[1], args[2], args[3], args[4], args[5]
}

type caddyFileParams struct {
	IngressUrls []string
}

func GenerateCaddyFile(args []string) {
	params := caddyFileParams{strings.Split(args[0], ",")}
	tmpl, err := Asset("templates/Caddyfile.tmpl")
	if err != nil {
		fatal("Can't read Caddyfile template" + err.Error())
	}
	t := template.Must(template.New("caddy").Delims("{{{", "}}}").Parse(string(tmpl)))

	t.Execute(os.Stdout, params)
}
