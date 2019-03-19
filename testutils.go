package main

import (
	"io/ioutil"
	"os"
	"testing"
)

func catchStdInStdOut(t *testing.T, input string, runnable func()) string {
	realStdin := os.Stdin
	realStdout := os.Stdout
	defer func() {
		os.Stdout = realStdout
		os.Stdin = realStdin
	}()
	fakeStdin, w, err := os.Pipe()
	dieOn(err, t)
	r, fakeStdout, err := os.Pipe()
	dieOn(err, t)
	os.Stdin = fakeStdin
	os.Stdout = fakeStdout
	w.WriteString(input)
	dieOn(w.Close(), t)
	runnable()
	dieOn(fakeStdout.Close(), t)
	newOutBytes, err := ioutil.ReadAll(r)
	dieOn(err, t)
	dieOn(r.Close(), t)
	dieOn(fakeStdin.Close(), t)
	return string(newOutBytes)
}

func catchStdOut(t *testing.T, runnable func()) string {
	realStdout := os.Stdout
	defer func() { os.Stdout = realStdout }()
	r, fakeStdout, err := os.Pipe()
	dieOn(err, t)
	os.Stdout = fakeStdout
	runnable()
	dieOn(fakeStdout.Close(), t)
	newOutBytes, err := ioutil.ReadAll(r)
	dieOn(err, t)
	dieOn(r.Close(), t)
	return string(newOutBytes)
}

func dieOn(err error, t *testing.T) {
	if err != nil {
		t.Fatal(err)
	}
}
