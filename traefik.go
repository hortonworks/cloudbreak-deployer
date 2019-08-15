package main

import (
	"fmt"
	"log"
	"os"
	"strings"
	"text/template"
)

type traefikTomlParams struct {
	CloudbreakURL       string
	PeriscopeURL        string
	DatalakeURL         string
	EnvironmentURL      string
	RedbeamsURL         string
	FreeIpaURL          string
	CaasURL             string
	ClusterProxyURL     string
	Environments2ApiURL string
	LocalDevList        string
}

func GenerateTraefikToml(args []string) {
	params := traefikTomlParams{args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9]}
	if len(params.LocalDevList) == 0 {
		fmt.Print("")
	} else {
		tmpl, err := Asset("templates/traefik.toml.tmpl")
		if err != nil {
			log.Fatal(err)
		}
		t := template.Must(template.New("traefik").Delims("{{{", "}}}").Funcs(template.FuncMap{
			"isLocal": func(p traefikTomlParams, service string) bool {
				return strings.Contains(p.LocalDevList, service)
			},
		}).Parse(string(tmpl)))
		t.Execute(os.Stdout, params)
	}
}
