#!/usr/bin/env bash
set -euo pipefail

PKG_MAKEFILE_REL="feeds/kenzo/luci-app-adguardhome/Makefile"
PKG_ROOT_I18N_REL="feeds/kenzo/luci-app-adguardhome/root/usr/lib/lua/luci/i18n"

usage() {
  cat <<'USAGE'
Usage: fix_luci-app-adguardhome_for_immortalwrt.sh

请在 OpenWrt/LEDE/ImmortalWrt 源码根目录执行本脚本：
  cd ~/immortalwrt
  bash /path/to/fix_luci-app-adguardhome_for_immortalwrt.sh

建议在 make menuconfig 之后、正式编译固件之前运行。
本脚本会为旧版 Lua CBI 的 luci-app-adguardhome 补上 luci-compat 依赖，
并删除主包 root 目录中预编译的 LuCI .lmo 翻译文件。

Options:
  -h, --help       Show this help
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

# --- 基础检查：必须在 OpenWrt/LEDE/ImmortalWrt 源码根目录执行 ---
if [ ! -f "include/toplevel.mk" ]; then
  echo "❌ 请在 OpenWrt/LEDE/ImmortalWrt 源码根目录执行（未发现 include/toplevel.mk）。" >&2
  echo "   示例：cd ~/immortalwrt && bash /path/to/$(basename "$0")" >&2
  exit 1
fi

MAKEFILE="$PKG_MAKEFILE_REL"
if [ ! -f "$MAKEFILE" ]; then
  echo "ERROR: package Makefile not found: $MAKEFILE" >&2
  echo "       请确认 feeds 已更新，并且 feeds/kenzo/luci-app-adguardhome 存在。" >&2
  exit 1
fi

echo "==> Preflight for luci-app-adguardhome"
echo "==> Expected use: run this after make menuconfig and before the full firmware build"
echo "==> Checking $PKG_MAKEFILE_REL"
if grep -Eq '^LUCI_DEPENDS:=.*\+luci-compat( |$)' "$MAKEFILE"; then
  echo "==> luci-compat dependency already present"
else
  backup="$MAKEFILE.bak.$(date +%Y%m%d-%H%M%S)"
  cp -p "$MAKEFILE" "$backup"
  tmpfile="$(mktemp)"

  awk '
    /^LUCI_DEPENDS:=/ && $0 !~ /\+luci-compat( |$)/ {
      if ($0 ~ /\+PACKAGE_/) {
        sub(/\+PACKAGE_/, "+luci-compat +PACKAGE_")
      } else {
        sub(/^LUCI_DEPENDS:=/, "LUCI_DEPENDS:=+luci-compat ")
      }
    }
    { print }
  ' "$MAKEFILE" > "$tmpfile"

  cat "$tmpfile" > "$MAKEFILE"
  rm -f "$tmpfile"
  echo "==> Added +luci-compat"
  echo "==> Backup saved: $backup"
fi

if [ -d "$PKG_ROOT_I18N_REL" ]; then
  lmo_count="$(find "$PKG_ROOT_I18N_REL" -maxdepth 1 -type f -name '*.lmo' | wc -l)"
  if [ "$lmo_count" -gt 0 ]; then
    echo "==> Removing prebuilt LuCI translation files from main package root"
    find "$PKG_ROOT_I18N_REL" -maxdepth 1 -type f -name '*.lmo' -print -delete
    rmdir "$PKG_ROOT_I18N_REL" 2>/dev/null || true
  else
    echo "==> No prebuilt .lmo files found in main package root"
  fi
else
  echo "==> No main-package LuCI i18n root directory found"
fi

echo "==> Preflight fixes applied."
echo "==> You can now run the full firmware build manually:"
echo '    make -j$(nproc) V=s'
