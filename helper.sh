#!/bin/bash

set -e

version() {
	echo "$@" | awk -F. '{ printf("%d%03d%03d\n", $1,$2,$3); }';
}

COMMAND=$1
shift

case "$COMMAND" in
  version)
	  version $@
	  ;;
  *)
    echo "Command not found"
    ;;
esac
