#!/bin/bash

if [[ "$USER" != "root" ]]; then
  echo "script must run as root"
  exit 1
fi

set -eux

export DEBIAN_FRONTEND=noninteractive

apt-get install -y python-pip
pip install pyroute2
