package main

import (
	"fmt"
	"log"
	"os"
	"text/template"
)

type traefikTomlParams struct {
	CloudbreakURL       string
	PeriscopeURL        string
	ConsumptionURL      string
	DatalakeURL         string
	EnvironmentURL      string
	RedbeamsURL         string
	FreeIpaURL          string
	ThunderheadURL      string
	ClusterProxyURL     string
	Environments2ApiURL string
	DatalakeApiURL      string
	DistroxApiURL       string
	AuditApiURL         string
	RecipesApiURL       string
	JAEGER_HOST         string
	LocalDevList        string
}

func GenerateTraefikToml(args []string) {
	params := traefikTomlParams{args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[10], args[11], args[12], args[13], args[14]}
	if len(params.LocalDevList) == 0 {
		fmt.Print("")
	} else {
		tmpl, err := Asset("templates/traefik.toml.tmpl")
		if err != nil {
			log.Fatal(err)
		}
		t := template.Must(template.New("traefik").Delims("{{{", "}}}").Funcs(template.FuncMap{
			"isLocal": func(p traefikTomlParams, service string) bool {
				return checkIfServiceInLocal(service, p.LocalDevList)
			},
		}).Parse(string(tmpl)))
		t.Execute(os.Stdout, params)
	}
}
