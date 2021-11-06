package main

import (
	"testing"
)

var expectedSingle string = `[file]

[backends]
    [backends.cloudbreak]
        [backends.cloudbreak.servers]
            [backends.cloudbreak.servers.server0]
            url = "cloudbreakURL"

[frontends]
    [frontends.cloudbreak-frontend]
    backend = "cloudbreak"
        [frontends.cloudbreak-frontend.routes.frontendrule]
        rule = "PathPrefix:/cb/"
        priority = 100

# Tracing definition
[tracing]
  backend = "jaeger"
  serviceName = "traefik"
  spanNameLimit = 0

  [tracing.jaeger]
    localAgentHostPort = "JAEGER_HOST:6831"
    samplingServerURL = "http://JAEGER_HOST:5778/sampling"
    samplingType = "const"
    samplingParam = 1.0
    traceContextHeaderName = "uber-trace-id"
    disableAttemptReconnecting = false
`

var expectedMulti string = `[file]

[backends]
    [backends.cloudbreak]
        [backends.cloudbreak.servers]
            [backends.cloudbreak.servers.server0]
            url = "cloudbreakURL"
    [backends.environment]
        [backends.environment.servers]
            [backends.environment.servers.server0]
            url = "environmentURL"
    [backends.periscope]
        [backends.periscope.servers]
            [backends.periscope.servers.server0]
            url = "periscopeURL"
    [backends.redbeams]
        [backends.redbeams.servers]
            [backends.redbeams.servers.server0]
            url = "redbeamsURL"
    [backends.freeipa]
        [backends.freeipa.servers]
            [backends.freeipa.servers.server0]
            url = "freeIpaURL"
    [backends.datalake-api]
        [backends.datalake-api.servers]
            [backends.datalake-api.servers.server0]
            url = "datalakeApiURL"

[frontends]
    [frontends.cloudbreak-frontend]
    backend = "cloudbreak"
        [frontends.cloudbreak-frontend.routes.frontendrule]
        rule = "PathPrefix:/cb/"
        priority = 100
    [frontends.environment-frontend]
    backend = "environment"
        [frontends.environment-frontend.routes.frontendrule]
        rule = "PathPrefix:/environmentservice/"
        priority = 100
    [frontends.periscope-frontend]
    backend = "periscope"
        [frontends.periscope-frontend.routes.frontendrule]
        rule = "PathPrefix:/as/"
        priority = 100
    [frontends.redbeams-frontend]
    backend = "redbeams"
        [frontends.redbeams-frontend.routes.frontendrule]
        rule = "PathPrefix:/redbeams/"
        priority = 100
    [frontends.freeipa-frontend]
    backend = "freeipa"
        [frontends.freeipa-frontend.routes.frontendrule]
        rule = "PathPrefix:/freeipa/"
        priority = 100
    [frontends.datalake-api-frontend]
    backend = "datalake-api"
        [frontends.datalake-api-frontend.routes.frontendrule]
        rule = "PathPrefix:/api/v1/datalake/"
        priority = 100

# Tracing definition
[tracing]
  backend = "jaeger"
  serviceName = "traefik"
  spanNameLimit = 0

  [tracing.jaeger]
    localAgentHostPort = "JAEGER_HOST:6831"
    samplingServerURL = "http://JAEGER_HOST:5778/sampling"
    samplingType = "const"
    samplingParam = 1.0
    traceContextHeaderName = "uber-trace-id"
    disableAttemptReconnecting = false
`

func TestNoLocalService(t *testing.T) {
	out := catchStdOut(t, func() {
		GenerateTraefikToml([]string{"cloudbreakURL", "periscopeURL", "datalakeURL", "environmentURL", "redbeamsURL", "freeIpaURL", "thunderheadMockURL", "clusterProxyURL", "environments2ApiURL", "datalakeApiURL", "distroxApiURL", "JAEGER_HOST", ""})
	})
	if len(out) > 0 {
		t.Errorf("If no local-dev services were defined, traefik.toml should be empty. out:'%s'", out)
	}
}

func TestCloudbreakLocalService(t *testing.T) {
	out := catchStdOut(t, func() {
		GenerateTraefikToml([]string{"cloudbreakURL", "periscopeURL", "datalakeURL", "environmentURL", "redbeamsURL", "freeIpaURL", "thunderheadURL", "clusterProxyURL", "environments2ApiURL", "datalakeApiURL", "distroxApiURL", "JAEGER_HOST", "cloudbreak"})
	})
	if out != expectedSingle {
		t.Errorf("If cloudbreak service was defined as local-dev, traefik.toml should contain the cloudbreak service related configs. out:'%s'\nexpected:'%s'", out, expectedSingle)
	}
}

func TestMultiLocalService(t *testing.T) {
	out := catchStdOut(t, func() {
		GenerateTraefikToml([]string{"cloudbreakURL", "periscopeURL", "datalakeURL", "environmentURL", "redbeamsURL", "freeIpaURL", "thunderheadURL", "clusterProxyURL", "environments2ApiURL", "datalakeApiURL", "distroxApiURL", "JAEGER_HOST", "cloudbreak,periscope,datalake-api,environment,redbeams,freeipa"})
	})
	if out != expectedMulti {
		t.Errorf("If services were defined as local-dev, traefik.toml should contain the defined services. out:'%s'", out)
	}
}
