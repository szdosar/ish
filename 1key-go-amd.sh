#!/bin/bash
### go 1.24.1 for amd64
set -e -o pipefail
curl -Lo go.tar.gz https://go.dev/dl/go1.24.1.linux-amd64.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go.tar.gz
rm -rf go.tar.gz
sudo rm /usr/bin/go
sudo ln -s /usr/local/go/bin/go /usr/bin/go
