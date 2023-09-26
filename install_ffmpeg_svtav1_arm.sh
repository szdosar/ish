#!/bin/bash

# 安装必要的依赖
sudo apt-get update
sudo apt-get install -y build-essential git yasm pkg-config

# 下载并安装cmake
wget https://github.com/Kitware/CMake/releases/download/v3.27.6/cmake-3.27.6-linux-aarch64.sh
chmod +x cmake-3.27.6-linux-aarch64.sh
sudo ./cmake-3.27.6-linux-aarch64.sh --prefix=/usr/local --skip-license

# 克隆并编译SVT-AV1
git clone --depth 1 https://github.com/AOMediaCodec/SVT-AV1.git
cd SVT-AV1
mkdir build && cd build
cmake ..
make -j$(nproc)
sudo make install

# 编译ffmpeg
cd ~
git clone https://github.com/FFmpeg/FFmpeg.git ffmpeg
cd ffmpeg
./configure --enable-libsvtav1
make -j$(nproc)
sudo make install

echo "完成！"
