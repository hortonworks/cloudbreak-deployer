package main

import (
	"regexp"
	"testing"
)

var inputVars = `
export CB_LOCAL_DEV_LIST=cloudbreak
export CAAS_MOCK_BIND_PORT=10080
export CAAS_MOCK_VOLUME_CONTAINER=/tmp/null
export CAAS_MOCK_VOLUME_HOST=/dev/null
export CAAS_URL=caas-api:8080
export CBD_CERT_ROOT_PATH=/Users/bbihari/prj/cbd-local/certs
export CBD_TRAEFIK_TLS=/certs/traefik/client.pem,/certs/traefik/client-key.pem
export CB_INSTANCE_NODE_ID=8a93ca4a-2004-4a41-9565-257060982457
export CB_PORT=8080
export CB_SHOW_TERMINATED_CLUSTERS_ACTIVE=false
export CB_SHOW_TERMINATED_CLUSTERS_DAYS=7
export CB_SHOW_TERMINATED_CLUSTERS_HOURS=0
export CB_SHOW_TERMINATED_CLUSTERS_MINUTES=0
export CLOUDBREAK_URL=http://host.docker.internal:9091
export COMMON_DB=commondb
export COMMON_DB_VOL=common
export DOCKER_IMAGE_CAAS_MOCK=hortonworks/cloudbreak-mock-caas
export DOCKER_IMAGE_CLOUDBREAK=hortonworks/cloudbreak
export DOCKER_IMAGE_CLOUDBREAK_DATALAKE=hortonworks/cloudbreak-datalake
export DOCKER_IMAGE_CLOUDBREAK_ENVIRONMENT=hortonworks/cloudbreak-environment
export DOCKER_IMAGE_CLOUDBREAK_PERISCOPE=hortonworks/cloudbreak-autoscale
export DOCKER_IMAGE_CLOUDBREAK_REDBEAMS=hortonworks/cloudbreak-redbeams
export DOCKER_IMAGE_CLOUDBREAK_FREEIPA=hortonworks/cloudbreak-freeipa
export DOCKER_IMAGE_CLOUDBREAK_WEB=hortonworks/hdc-web
export DOCKER_NETWORK_NAME=default
export DOCKER_TAG_CAAS_MOCK=2.10.0-dev.669
export DOCKER_TAG_CLOUDBREAK=2.10.0-dev.669
export DOCKER_TAG_DATALAKE=2.10.0-dev.669
export DOCKER_TAG_ENVIRONMENT=2.10.0-dev.805
export DOCKER_TAG_HAVEGED=1.1.0
export DOCKER_TAG_LOGROTATE=1.0.1
export DOCKER_TAG_PERISCOPE=2.10.0-dev.669
export DOCKER_TAG_POSTGRES=9.6.1-alpine
export DOCKER_TAG_REDBEAMS=2.10.0-dev.809
export DOCKER_TAG_TRAEFIK=v1.7.9-alpine
export DOCKER_TAG_UAA=3.6.5-pgupdate
export DOCKER_TAG_ULUWATU=2.10.0-dev.669
export DPS_REPO=
export DPS_VERSION=latest
export HTTPS_PROXYFORCLUSTERCONNECTION=false
export PERISCOPE_URL=http://periscope:8080
export PUBLIC_HTTPS_PORT=443
export PUBLIC_HTTP_PORT=80
export PUBLIC_IP=127.0.0.1
export TRAEFIK_MAX_IDLE_CONNECTION=100
export UAA_CLOUDBREAK_ID=cloudbreak
export UAA_DATALAKE_ID=datalake
export UAA_ENVIRONMENT_ID=environment
export UAA_PERISCOPE_ID=periscope
export UAA_REDBEAMS_ID=redbeams
export UAA_PORT=8089
export UAA_ULUWATU_ID=uluwatu
export ULUWATU_FRONTEND_RULE=PathPrefix:/
export ULUWATU_VOLUME_CONTAINER=/tmp/null
export ULUWATU_VOLUME_HOST=/dev/null
export ULU_NODE_TLS_REJECT_UNAUTHORIZED=0
export VAULT_BIND_PORT=8200
export VAULT_CONFIG_FILE=vault-config.hcl
export VAULT_DOCKER_IMAGE=vault
export VAULT_DOCKER_IMAGE_TAG=1.0.1
export VAULT_ROOT_TOKEN=s.1XLr7GJsH3jYY5lzGHcwpevY
`
var dpsVar = `
export DPS_REPO=test.dps.repo
`

func TestComposeGenerationWithoutDps(t *testing.T) {
	out := catchStdInStdOut(t, inputVars, func() {
		GenerateComposeYaml([]string{})
	})
	should := []string{`(?m)^\s*periscope:`, `(?m)^\s*datalake:`, `(?m)^\s*redbeams:`}
	shouldnt := []string{`(?m)^\s*cloudbreak:`, `(?m)^\s*cluster-proxy:`, `(?m)^\s*core-gateway:`}
	for _, s := range should {
		re := regexp.MustCompile(s)
		if res := re.FindString(out); len(res) == 0 {
			t.Errorf("Can't find service '%s' in output.", s)
		}
	}
	for _, s := range shouldnt {
		re := regexp.MustCompile(s)
		if res := re.FindString(out); len(res) != 0 {
			t.Errorf("Found service '%s'.", s)
		}
	}
}

func TestComposeGenerationWithDps(t *testing.T) {
	out := catchStdInStdOut(t, inputVars+dpsVar, func() {
		GenerateComposeYaml([]string{})
	})
	should := []string{`(?m)^\s*periscope:`, `(?m)^\s*datalake:`, `(?m)^\s*redbeams:`, `(?m)^\s*caas-api:`, `(?m)^\s*cluster-proxy:`, `(?m)^\s*core-gateway:`}
	shouldnt := []string{`(?m)^\s*cloudbreak:`}
	for _, s := range should {
		re := regexp.MustCompile(s)
		if res := re.FindString(out); len(res) == 0 {
			t.Errorf("Can't find service '%s' in output.", s)
		}
	}
	for _, s := range shouldnt {
		re := regexp.MustCompile(s)
		if res := re.FindString(out); len(res) != 0 {
			t.Errorf("Found service '%s'.", s)
		}
	}
}

func TestEscapeStringComposeYaml(t *testing.T) {
	var escapeTests = []struct {
		name      string
		in        string
		outSingle string
		outDouble string
	}{
		{"Single quote test.", `asdf 'as'df' asdf`, `asdf ''as''df'' asdf`, `asdf 'as'df' asdf`},
		{"Double quote test.", `asdf "as"df" asdf`, `asdf "as"df" asdf`, `asdf \"as\"df\" asdf`},
		{"Dollar quote test.", `asdf $as$df$ asdf`, `asdf $$as$$df$$ asdf`, `asdf $$as$$df$$ asdf`},
		{"Backslash quote test.", `asdf \as\df\ asdf`, `asdf \as\df\ asdf`, `asdf \\as\\df\\ asdf`},
	}
	for _, c := range escapeTests {
		if escapeStringComposeYaml(c.in, "'") != c.outSingle {
			t.Errorf("Wrong yaml escaping: %s, was:'%s', expected:'%s'", c.name, escapeStringComposeYaml(c.in, "'"), c.outSingle)
		}
		if escapeStringComposeYaml(c.in, "\"") != c.outDouble {
			t.Errorf("Wrong yaml escaping: %s, was:'%s', expected:'%s'", c.name, escapeStringComposeYaml(c.in, "\""), c.outDouble)
		}
	}
}
