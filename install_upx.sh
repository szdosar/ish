#!/bin/bash
set -e

echo "🛠️ 正在安装依赖..."
sudo apt update
sudo apt install -y build-essential git zlib1g-dev cmake

echo "📦 正在克隆 UPX 源码（含子模块）..."
git clone --recursive https://github.com/upx/upx.git
cd upx

echo "⚙️ 正在编译 UPX（release 模式）..."
cmake -S . -B build/release -DCMAKE_BUILD_TYPE=Release
cmake --build build/release -j$(nproc)

echo "📥 正在安装到 /usr/local/bin..."
sudo cp build/release/upx /usr/local/bin/

echo "✅ 安装完成，UPX 版本如下："
upx --version
