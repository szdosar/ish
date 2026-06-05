#!/usr/bin/env bash
set -euo pipefail

OPENWRT_DIR="${OPENWRT_DIR:-$HOME/immortalwrt}"
PKG_MAKEFILE_REL="feeds/kenzo/luci-app-adguardhome/Makefile"
PKG_ROOT_I18N_REL="feeds/kenzo/luci-app-adguardhome/root/usr/lib/lua/luci/i18n"

usage() {
  cat <<'USAGE'
Usage: fix_luci-app-adguardhome_for_lede.sh [--openwrt-dir PATH]

Run this after make menuconfig and before the full firmware build. It prepares
luci-app-adguardhome for this OpenWrt/LEDE/ImmortalWrt tree by ensuring the old Lua CBI LuCI app
depends on luci-compat and by removing prebuilt LuCI .lmo translation files
from the main package root.

Options:
  --openwrt-dir PATH  OpenWrt/LEDE/ImmortalWrt source tree path. Default: $HOME/immortalwrt or $OPENWRT_DIR
  -h, --help       Show this help
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --openwrt-dir)
      [ "$#" -ge 2 ] || { echo "ERROR: --openwrt-dir requires a path" >&2; exit 2; }
      OPENWRT_DIR="$2"
      shift 2
      ;;
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

if [ ! -f "$OPENWRT_DIR/rules.mk" ]; then
  echo "ERROR: not an OpenWrt/LEDE/ImmortalWrt tree: $OPENWRT_DIR" >&2
  exit 1
fi

MAKEFILE="$OPENWRT_DIR/$PKG_MAKEFILE_REL"
if [ ! -f "$MAKEFILE" ]; then
  echo "ERROR: package Makefile not found: $MAKEFILE" >&2
  exit 1
fi

cd "$OPENWRT_DIR"

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
