#!/bin/bash
### go 1.19 for arm64
set -e -o pipefail
curl -Lo go.tar.gz https://go.dev/dl/go1.19.5.linux-arm64.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go.tar.gz
rm go.tar.gz
ln -s /usr/local/go/bin/go /usr/bin/go

### caddy for naive
go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest
~/go/bin/xcaddy build --with github.com/caddyserver/forwardproxy@caddy2=github.com/klzgrad/forwardproxy@naive
