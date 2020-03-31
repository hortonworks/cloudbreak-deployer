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
`

var expectedMulti string = `[file]

[backends]
    [backends.cloudbreak]
        [backends.cloudbreak.servers]
            [backends.cloudbreak.servers.server0]
            url = "cloudbreakURL"
    [backends.datalake]
        [backends.datalake.servers]
            [backends.datalake.servers.server0]
            url = "datalakeURL"
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

[frontends]
    [frontends.cloudbreak-frontend]
    backend = "cloudbreak"
        [frontends.cloudbreak-frontend.routes.frontendrule]
        rule = "PathPrefix:/cb/"
        priority = 100
    [frontends.datalake-frontend]
    backend = "datalake"
        [frontends.datalake-frontend.routes.frontendrule]
        rule = "PathPrefix:/dl/"
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
`

func TestNoLocalService(t *testing.T) {
	out := catchStdOut(t, func() {
		GenerateTraefikToml([]string{"cloudbreakURL", "periscopeURL", "datalakeURL", "environmentURL", "redbeamsURL", "freeIpaURL", "caasURL", "clusterProxyURL", "environments2ApiURL", "datalakeApiURL", ""})
	})
	if len(out) > 0 {
		t.Errorf("If no local-dev services were defined, traefik.toml should be empty. out:'%s'", out)
	}
}

func TestCloudbreakLocalService(t *testing.T) {
	out := catchStdOut(t, func() {
		GenerateTraefikToml([]string{"cloudbreakURL", "periscopeURL", "datalakeURL", "environmentURL", "redbeamsURL", "freeIpaURL", "caasURL", "clusterProxyURL", "environments2ApiURL", "datalakeApiURL", "cloudbreak"})
	})
	if out != expectedSingle {
		t.Errorf("If cloudbreak service was defined as local-dev, traefik.toml should contain the cloudbreak service related configs. out:'%s'\nexpected:'%s'", out, expectedSingle)
	}
}

func TestMultiLocalService(t *testing.T) {
	out := catchStdOut(t, func() {
		GenerateTraefikToml([]string{"cloudbreakURL", "periscopeURL", "datalakeURL", "environmentURL", "redbeamsURL", "freeIpaURL", "caasURL", "clusterProxyURL", "environments2ApiURL", "datalakeApiURL", "cloudbreak,periscope,datalake,environment,redbeams,freeipa"})
	})
	if out != expectedMulti {
		t.Errorf("If services were defined as local-dev, traefik.toml should contain the defined services. out:'%s'", out)
	}
}
