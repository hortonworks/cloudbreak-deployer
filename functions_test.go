package main

import "testing"

func TestServiceURL(t *testing.T) {
	var testCases = []struct {
		args   []string
		result string
	}{
		{[]string{"cloudbreak", "bridge.address", ""}, "http://cloudbreak:8080"},
		{[]string{"cloudbreak", "bridge.address", "cloudbreak,periscope"}, "http://bridge.address:9091"},
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
