#!/bin/bash

if [[ "$USER" != "root" ]]; then
  echo "script must run as root"
  exit 1
fi

set -eux

go get github.com/nats-io/gnatsd
go get github.com/nats-io/go-nats
