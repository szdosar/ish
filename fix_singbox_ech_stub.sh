#!/usr/bin/env bash
# fix_singbox_ech_stub.sh
# 安全修补 sing-box 的 ech_tag_stub.go “编译炸弹”
# 只负责查找并注释提示行；若未解压则最小化 prepare，一切失败不阻断主流程

set -euo pipefail

# --- 基础检查：必须在 OpenWrt 源码根目录执行 ---
if [ ! -f "include/toplevel.mk" ]; then
  echo "❌ 请在 OpenWrt 源码根目录执行（未发现 include/toplevel.mk）。"
  exit 1
fi

find_files() {
  find build_dir -type f -name ech_tag_stub.go 2>/dev/null || true
}

patch_all() {
  local files="$1"
  echo "✅ 找到以下 ech_tag_stub.go："
  echo "${files}"
  echo

  while IFS= read -r f; do
    [ -n "$f" ] || continue

    # 仅当包含提示行时才处理；已注释则跳过
    if grep -q "Due to the migration to stdlib" "$f"; then
      if ! grep -q "^// .*Due to the migration to stdlib" "$f"; then
        # 备份（若不存在再备份，便于多次运行幂等）
        cp -n "$f" "$f.bak" 2>/dev/null || true
        # 注释该行
        sed -i '/Due to the migration to stdlib/ s/^/\/\/ /' "$f"
        echo "🔧 已修补 -> $f"
      else
        echo "✔️ 已是注释状态 -> $f（跳过）"
      fi
    else
      echo "ℹ️ 未发现提示行 -> $f（可能上游已移除，跳过）"
    fi
  done <<< "${files}"

  echo
  echo "✅ 修补完成。"
}

main() {
  # 第一次查找
  files="$(find_files)"

  if [ -z "${files}" ]; then
    echo "ℹ️ 未找到 ech_tag_stub.go，尝试最小化准备源码（先装 host 工具，再 prepare）..."
    # 合并目标，若失败则温和退出，避免影响主流程
    if ! make tools/install package/feeds/small/sing-box/prepare V=s; then
      echo "⚠️ host 工具安装或 prepare 失败，跳过补丁（交给原流程处理）。"
      exit 0
    fi
    # 第二次查找
    files="$(find_files)"
  fi

  if [ -z "${files}" ]; then
    echo "🟡 仍未找到 ech_tag_stub.go（可能上游已移除或版本不同），跳过补丁。"
    exit 0
  fi

  patch_all "${files}"
}

main "$@"
