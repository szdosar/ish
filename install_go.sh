#!/bin/bash

# 获取系统架构
ARCH=$(dpkg --print-architecture)

# 设定 Go 官方架构名称
case "$ARCH" in
    amd64)   GO_ARCH="amd64" ;;
    arm64)   GO_ARCH="arm64" ;;
    armhf)   GO_ARCH="armv6l" ;;  # 兼容 armv7
    *) 
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# 检查是否有命令行参数
if [[ -n "$1" ]]; then
    GO_VERSION="$1"
    echo "Version specified by argument: $GO_VERSION"
else
    # 无参数，提示用户输入
    echo "Enter Go version (or press Enter to get the latest version in 15 seconds):"
    read -t 15 GO_VERSION

    # 如果仍未输入，自动获取最新版
    if [[ -z "$GO_VERSION" ]]; then
        echo "Fetching latest Go version..."
        GO_VERSION=$(curl -sL https://go.dev/dl/ | grep -oE 'go[0-9]+\.[0-9]+\.[0-9]+' | head -n 1 | sed 's/go//')
        if [[ -z "$GO_VERSION" ]]; then
            echo "Failed to fetch latest Go version!"
            exit 1
        fi
        echo "Latest Go version detected: $GO_VERSION"
    else
        echo "User-specified Go version: $GO_VERSION"
    fi
fi

# 生成下载链接
GO_URL="https://go.dev/dl/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz"

# 执行下载
echo "Downloading Go $GO_VERSION for architecture $ARCH..."
curl -Lo go.tar.gz "$GO_URL"

# 显示下载链接
echo "Download URL: $GO_URL"

# 安装 Go
echo "Installing Go $GO_VERSION..."
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go.tar.gz
rm -rf go.tar.gz

# 软链接
sudo rm -f /usr/bin/go
sudo ln -s /usr/local/go/bin/go /usr/bin/go

# 验证安装
echo "Go installation complete!"
go version
