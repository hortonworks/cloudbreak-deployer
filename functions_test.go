package main

import (
	"regexp"
	"testing"
)

func TestServiceURL(t *testing.T) {
	var testCases = []struct {
		args   []string
		result string
	}{
		{[]string{"cloudbreak", "bridge.address", "", "http://", "9091", "8080"}, "http://cloudbreak:8080"},
		{[]string{"cloudbreak", "bridge.address", "cloudbreak", "http://", "9091", "8080"}, "http://bridge.address:9091"},
	}

	for _, c := range testCases {
		out := catchStdOut(t, func() {
			ServiceURL(c.args)
		})
		if out != c.result {
			t.Errorf("Service URL generated:'%s' should be '%s'.", out, c.result)
		}
	}
}

func TestBinVersion(t *testing.T) {
	Version = "version"
	GitRevision = "gitrevision"
	expected := "version-gitrevision\n"
	out := catchStdOut(t, func() {
		BinVersion([]string{})
	})
	if out != expected {
		t.Errorf("Version should be '%s', was: '%s'", expected, out)
	}

}

func TestGenerateCaddyFileSingle(t *testing.T) {
	should := []string{`(?m)^\s*localhost:`}
	out := catchStdOut(t, func() {
		GenerateCaddyFile([]string{"localhost"})
	})
	t.Log(out)
	for _, s := range should {
		re := regexp.MustCompile(s)
		if res := re.FindString(out); len(res) == 0 {
			t.Errorf("Can't find service '%s' in output.", s)
		}
	}
}

func TestGenerateCaddyFileMultiple(t *testing.T) {
	should := []string{`(?m)^\s*localhost:`, `(?m)^\s*localhost2:`}
	out := catchStdOut(t, func() {
		GenerateCaddyFile([]string{"localhost,localhost2"})
	})
	t.Log(out)
	for _, s := range should {
		re := regexp.MustCompile(s)
		if res := re.FindString(out); len(res) == 0 {
			t.Errorf("Can't find service '%s' in output.", s)
		}
	}
}

func TestHostFromURL(t *testing.T) {
	var testCases = []struct {
		args   []string
		result string
	}{
		{[]string{"foo.com:1234"}, "foo.com"},
		{[]string{"foo.com:1234/bar/blah/"}, "foo.com"},
		{[]string{"http://foo.com:1234"}, "foo.com"},
		{[]string{"https://foo.com:1234/bar/blah/"}, "foo.com"},
	}

	for _, c := range testCases {
		out := catchStdOut(t, func() {
			HostFromURL(c.args)
		})
		if out != c.result {
			t.Errorf("Host for URL '%s': got '%s', expected '%s'.", c.args, out, c.result)
		}
	}
}

func TestPortFromURL(t *testing.T) {
	var testCases = []struct {
		args   []string
		result string
	}{
		{[]string{"foo.com:1234"}, "1234"},
		{[]string{"foo.com:1234/bar/blah/"}, "1234"},
		{[]string{"http://foo.com:1234"}, "1234"},
		{[]string{"https://foo.com:1234/bar/blah/"}, "1234"},
	}

	for _, c := range testCases {
		out := catchStdOut(t, func() {
			PortFromURL(c.args)
		})
		if out != c.result {
			t.Errorf("Host for URL '%s': got '%s', expected '%s'.", c.args, out, c.result)
		}
	}
}
