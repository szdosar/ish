#!/usr/bin/env bash
# fix_singbox_ech_stub.sh
# 自动修补 sing-box 的 ech_tag_stub.go 编译“炸弹”
# 逻辑：先找 -> 找不到就 prepare -> 再找 -> 找到就修补所有匹配文件 -> 找不到就跳过

set -euo pipefail

prepare_once() {
  echo "ℹ️ 未找到 ech_tag_stub.go，尝试执行 prepare..."
  # 优先使用目标包的 prepare（更快更稳）
  if make package/feeds/small/sing-box/prepare V=s; then
    echo "✅ prepare 完成。"
    return 0
  fi

  # 兜底：某些环境下需要先 update/install
  echo "ℹ️ 尝试更新并安装 feed..."
  ./scripts/feeds update small || true
  ./scripts/feeds install sing-box || true
  make package/feeds/small/sing-box/prepare V=s
  echo "✅ prepare 完成（经由 feed 更新）。"
}

patch_all() {
  local files="$1"
  echo "✅ 找到以下 ech_tag_stub.go："
  echo "$files"
  echo

  while IFS= read -r f; do
    [ -n "$f" ] || continue
    # 备份：若不存在备份再备份，避免 CI 里重复执行覆盖
    if [ ! -f "$f.bak" ]; then
      cp "$f" "$f.bak"
      echo "🗂 备份 -> $f.bak"
    fi

    # 只在包含提示行时进行注释；若已注释则跳过
    if grep -q "Due to the migration to stdlib" "$f"; then
      # 若该行尚未被注释，则注释之
      if ! grep -q "^// .*Due to the migration to stdlib" "$f"; then
        sed -i '/Due to the migration to stdlib/ s/^/\/\/ /' "$f"
        echo "🔧 已修补 -> $f"
      else
        echo "✔️ 已是注释状态 -> $f（跳过）"
      fi
    else
      echo "ℹ️ 提示行不存在 -> $f（可能已被上游移除，跳过）"
    fi
  done <<< "$files"

  echo
  echo "✅ 修补完成。现在可以编译 sing-box 了："
  echo "   make package/feed
