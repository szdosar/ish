#!/bin/bash
### go 1.22.5 for arm64
set -e -o pipefail
curl -Lo go.tar.gz https://go.dev/dl/go1.22.5.linux-arm64.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go.tar.gz
rm go.tar.gz
sudo ln -s /usr/local/go/bin/go /usr/bin/go
