#!/bin/bash

set -e

SYSCTL_FILE="/etc/sysctl.d/99-disable-ipv6.conf"
BACKUP_FILE="${SYSCTL_FILE}.bak"

# 备份旧文件
if [ -f "$SYSCTL_FILE" ] && [ ! -f "$BACKUP_FILE" ]; then
    echo "🔁 备份原始 sysctl 文件到 $BACKUP_FILE"
    sudo cp "$SYSCTL_FILE" "$BACKUP_FILE"
elif [ -f "$BACKUP_FILE" ]; then
    echo "✅ 已存在备份文件：$BACKUP_FILE"
else
    echo "📄 无原始 sysctl IPv6 配置文件，无需备份"
fi

# 写入禁用 IPv6 的设置
echo "🛠️ 写入禁用 IPv6 设置到 $SYSCTL_FILE"
sudo tee "$SYSCTL_FILE" > /dev/null <<EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.enp2s0.disable_ipv6 = 1
EOF

# 应用设置
echo "🔄 应用 sysctl 设置..."
sudo sysctl --system

# 检查结果
echo "✅ 当前 IPv6 状态（应无 inet6 地址）:"
ip a | grep inet6 || echo "（已无 IPv6 地址）"

echo ""
echo "📌 如需还原 IPv6，请运行："
echo "    sudo mv $BACKUP_FILE $SYSCTL_FILE && sudo sysctl --system"
