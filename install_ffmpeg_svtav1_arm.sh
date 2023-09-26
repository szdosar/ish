#!/bin/bash

# 进入/tmp目录
cd /tmp
rm -rf SVT-AV1-tmp
mkdir -p SVT-AV1-tmp && cd SVT-AV1-tmp

# 安装必要的依赖
sudo apt-get update
sudo apt-get install -y build-essential git yasm pkg-config

# 下载并安装cmake
wget https://github.com/Kitware/CMake/releases/download/v3.27.6/cmake-3.27.6-linux-aarch64.sh
chmod +x cmake-3.27.6-linux-aarch64.sh
sudo ./cmake-3.27.6-linux-aarch64.sh --prefix=/usr/local --skip-license

# 克隆并编译SVT-AV1
git clone --depth 1 https://gitlab.com/AOMediaCodec/SVT-AV1.git
cd SVT-AV1
mkdir build && cd build
cmake ..
make -j$(nproc)
sudo make install

# 编译ffmpeg
cd /tmp
rm -rf SVT-AV1-tmp
rm -rf ffmpeg-tmp
mkdir -p ffmpeg-tmp && cd ffmpeg-tmp

if [ ! -d "ffmpeg" ]; then
  git clone https://github.com/FFmpeg/FFmpeg.git ffmpeg
fi
cd ffmpeg
./configure --enable-libsvtav1
make -j$(nproc)
sudo make install

echo "完成！"
