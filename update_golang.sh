#!/bin/bash

# 设定所需的最低版本
required_version="1.22"

# 从Makefile中提取Golang当前版本
current_version=$(grep 'GO_VERSION_MAJOR_MINOR:=' feeds/packages/lang/golang/golang/Makefile | cut -d '=' -f2)

# 比较版本函数
version_lte() {
    [ "$1" = "$(echo -e "$1\n$2" | sort -V | head -n1)" ]
}

# 检查版本是否满足要求
if version_lte "$required_version" "$current_version"; then
    echo "当前Golang版本为 $current_version，满足最低要求版本 $required_version，无需更新。"
else
    echo "当前Golang版本为 $current_version，不满足最低要求版本 $required_version，开始更新..."
    rm -rf feeds/packages/lang/golang
    git clone https://github.com/sbwml/packages_lang_golang -b 22.x feeds/packages/lang/golang
fi
