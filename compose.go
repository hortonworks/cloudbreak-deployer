package main

import (
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"strings"
	"text/template"
)

func GenerateComposeYaml(args []string) {
	bytes, err := ioutil.ReadAll(os.Stdin)
	if err != nil {
		log.Fatal(err)
	}
	dataMap := convertToMap(&bytes)
	tmpl, err := Asset("templates/compose-main.tmpl")
	if err != nil {
		log.Fatal(err)
	}
	t := template.Must(template.New("compose").Delims("{{{", "}}}").Funcs(template.FuncMap{
		"get": func(m map[string]string, key string) string {
			return m[key]
		},
		"getEscaped": func(m map[string]string, key string) string {
			return escapeStringComposeYaml(m[key], "'")
		},
	}).Parse(string(tmpl)))
	localDevList := dataMap["CB_LOCAL_DEV_LIST"]

	if dataMap["CAAS_MOCK"] == "true" || len(dataMap["DPS_REPO"]) == 0 {
		insertIntoTemplate(t, "no-dps")
		insertIntoTemplateIfNotLocal(t, localDevList, "auth-mock")

		if len(dataMap["UMS_HOST"]) != 0 {
			insertIntoTemplate(t, "core-gateway")
		} else {
			insertIntoTemplate(t, "cb-traefik")
		}
	} else {
		insertIntoTemplate(t, "core-gateway")
		insertIntoTemplate(t, "dps")
		insertIntoTemplateIfNotLocal(t, localDevList, "cluster-proxy")
	}
	insertIntoTemplateIfNotLocal(t, localDevList, "cloudbreak")
	insertIntoTemplateIfNotLocal(t, localDevList, "datalake")
	insertIntoTemplateIfNotLocal(t, localDevList, "periscope")
	insertIntoTemplateIfNotLocal(t, localDevList, "redbeams")

	t.Execute(os.Stdout, dataMap)
}

func insertIntoTemplate(t *template.Template, service string) {
	templ, err := Asset(fmt.Sprintf("templates/compose-%s.tmpl", service))
	if err != nil {
		log.Fatal(err)
	}
	t = template.Must(t.Parse(string(templ)))
}

func insertIntoTemplateIfNotLocal(t *template.Template, localDevList string, service string) {
	if !strings.Contains(localDevList, service) {
		insertIntoTemplate(t, service)
	}
}

func convertToMap(in *[]byte) map[string]string {
	result := make(map[string]string)
	vars := strings.Split(string(*in), "\n")
	for _, v := range vars {
		if len(v) > 0 {
			v = strings.TrimPrefix(v, "export ")
			ind := strings.Index(v, "=")
			result[v[:ind]] = v[ind+1:]
		}
	}
	return result
}

func escapeStringComposeYaml(in string, delimiter string) string {
	result := in
	if delimiter == "'" {
		result = strings.ReplaceAll(result, "'", "''")
		result = strings.ReplaceAll(result, "$", "$$")
	} else if delimiter == "\"" {
		result = strings.ReplaceAll(result, "\\", "\\\\")
		result = strings.ReplaceAll(result, "\"", "\\\"")
		result = strings.ReplaceAll(result, "$", "$$")
	}
	return result
}
