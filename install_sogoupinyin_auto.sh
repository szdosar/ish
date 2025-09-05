#!/bin/bash
# 通用 Sogou Pinyin 安装脚本（支持参数指定 .deb 安装包）
# 作者：ChatGPT 为 dosar 编写

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

# ---------- 检测系统信息 ----------
OS_ID=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
OS_VERSION_ID=$(grep '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
OS_FULL="$OS_ID $OS_VERSION_ID"

echo "🖥️ 检测到当前系统：$OS_FULL"

# ---------- Debian 特有操作 ----------
if [[ "$OS_ID" == "debian" && "$OS_VERSION_ID" == "13" ]]; then
    echo "📀 正在禁用 cdrom 源以避免 apt 报错..."
    sudo sed -i '/^deb cdrom:/s/^/#/' /etc/apt/sources.list
fi

# ---------- 更新软件源 ----------
echo "🔄 更新软件包索引..."
sudo apt update

# ---------- 安装 fcitx4 所需依赖 ----------
echo "📦 安装 fcitx4 和相关依赖..."
sudo apt install -y fcitx fcitx-config-gtk \
    fcitx-frontend-gtk2 fcitx-frontend-gtk3 \
    fcitx-frontend-qt5 fcitx-module-x11 im-config

# ---------- Ubuntu 特有操作 ----------
if [[ "$OS_ID" == "ubuntu" && "$OS_VERSION_ID" == "24.04" ]]; then
    echo "🧩 安装 fcitx-ui-classic（显示输入法图标）..."
    sudo apt install -y fcitx-ui-classic
fi

# ---------- 安装 sogoupinyin ----------
echo "🚀 安装 sogoupinyin..."
sudo dpkg -i "$DEB_FILE" || sudo apt -f install -y

# ---------- 写入 .xprofile ----------
PROFILE_FILE="$HOME/.xprofile"
echo "🛠️ 设置输入法环境变量到 $PROFILE_FILE..."

if [ ! -f "$PROFILE_FILE" ]; then
    touch "$PROFILE_FILE"
fi

# 清除旧设置
sed -i '/GTK_IM_MODULE/d;/QT_IM_MODULE/d;/XMODIFIERS/d' "$PROFILE_FILE"

cat <<EOF >> "$PROFILE_FILE"

# ===== Sogou Pinyin fcitx4 环境变量 =====
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS="@im=fcitx"
# =======================================
EOF

# ---------- 使用 fci
