#!/bin/bash

echo "开始清理Ubuntu 22.04 LTS服务器版的磁盘空间..."

# 显示清理前的磁盘空间使用情况
echo "清理前的磁盘空间使用情况："
df -h

# 更新包列表
sudo apt update

# 清理包缓存
sudo apt clean

# 删除不需要的包和依赖
sudo apt autoremove -y

# 清理已下载但未安装的包
sudo apt autoclean

# 清空系统缓存
sudo sync; sudo sysctl -w vm.drop_caches=3

# 清理系统日志
sudo journalctl --vacuum-time=3d

# 删除临时文件
sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*

# 删除过期的快照（如果使用了snap）
sudo snap set system refresh.retain=2
sudo snap list --all | awk '/disabled/{print $1, $3}' | while read snapname revision; do sudo snap remove "$snapname" --revision="$revision"; done

# 显示清理后的磁盘空间使用情况
echo "清理后的磁盘空间使用情况："
df -h

echo "清理完成！"
