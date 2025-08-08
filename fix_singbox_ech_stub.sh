#!/bin/bash
# fix_singbox_ech_stub.sh
# 自动查找并修补所有 ech_tag_stub.go 编译错误

# 查找所有 ech_tag_stub.go
TARGET_FILES=$(find build_dir -type f -name ech_tag_stub.go 2>/dev/null)

if [ -z "$TARGET_FILES" ]; then
    echo "❌ 没找到 ech_tag_stub.go 文件，请先运行 prepare 解压源码："
    echo "   make package/feeds/small/sing-box/prepare V=s"
    exit 1
fi

echo "✅ 找到以下文件："
echo "$TARGET_FILES"

# 逐个修补
for file in $TARGET_FILES; do
    cp "$file" "$file.bak"
    sed -i '/Due to the migration to stdlib/ s/^/\/\/ /' "$file"
    echo "🔧 已修补 $file"
done

echo "✅ 所有 ech_tag_stub.go 已修补完成，现在可以编译："
echo "   make package/feeds/small/sing-box/compile V=s"
