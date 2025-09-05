#!/bin/bash
# 通用 Sogou Pinyin 安装脚本（支持参数指定 .deb 安装包）

set -e

# ---------- 获取参数（.deb 文件名） ----------
DEB_FILE="$1"

if [ -z "$DEB_FILE" ]; then
    echo "❌ 未指定安装包文件名。"
    echo "用法：$0 sogoupinyin_x.x.x.xxx_amd64.deb"
    exit 1
fi

echo "🔍 检查是否存在安装包 $DEB_FILE..."
if [ ! -f "$DEB_FILE" ]; then
    echo "❌ 找不到安装包：$DEB_FILE"
    echo "请将安装包 $DEB_FILE 放到当前目录后再运行本脚本。"
    exit 1
fi
