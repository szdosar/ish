#!/bin/bash
### go 1.22.5 for amd64
set -e -o pipefail
curl -Lo go.tar.gz https://go.dev/dl/go1.22.5.linux-amd64.tar.gz
sudo rm -rf /usr/bin/go
sudo tar -C ~ -xzf go.tar.gz
sudo mv ~/go/bin/go /usr/bin/
rm go.tar.gz
