#!/bin/sh
# Reset default locale to zh_CN.UTF-8 on Debian 13+ (POSIX sh)

set -eu

TARGET_LOCALE="zh_CN.UTF-8"
LOCALE_GEN="/etc/locale.gen"
DEFAULT_LOCALE="/etc/default/locale"

if [ "$(id -u)" -ne 0 ]; then
  echo "请用 root 权限运行（sudo -i 或 su -）。"
  exit 1
fi

# 1) 确保 locales 包存在
if ! dpkg -s locales >/dev/null 2>&1; then
  apt-get update -y
  DEBIAN_FRONTEND=noninteractive apt-get install -y locales
fi

# 2) 启用 zh_CN.UTF-8
[ -f "$LOCALE_GEN" ] || touch "$LOCALE_GEN"
cp -a "$LOCALE_GEN" "${LOCALE_GEN}.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

if grep -Eq '^[# ]*zh_CN\.UTF-8[[:space:]]+UTF-8' "$LOCALE_GEN"; then
  sed -i 's/^[# ]*zh_CN\.UTF-8[[:space:]]\+UTF-8/zh_CN.UTF-8 UTF-8/' "$LOCALE_GEN"
else
  printf '%s\n' 'zh_CN.UTF-8 UTF-8' >> "$LOCALE_GEN"
fi

# 3) 生成 locale
locale-gen

# 4) 更新默认值
update-locale LANG="$TARGET_LOCALE" LANGUAGE="zh_CN:zh"

# 5) 移除 LC_ALL（避免覆盖）
if [ -f "$DEFAULT_LOCALE" ] && grep -q '^LC_ALL=' "$DEFAULT_LOCALE"; then
  cp -a "$DEFAULT_LOCALE" "${DEFAULT_LOCALE}.bak.$(date +%Y%m%d%H%M%S)"
  grep -v '^LC_ALL=' "$DEFAULT_LOCALE" > "${DEFAULT_LOCALE}.tmp"
  mv "${DEFAULT_LOCALE}.tmp" "$DEFAULT_LOCALE"
fi

echo "✅ 已将默认语言切换为 $TARGET_LOCALE"
echo "新开终端 / 重启后自动生效。"
echo "如果要立即在当前会话生效，请运行："
echo "  export LANG=$TARGET_LOCALE LANGUAGE='zh_CN:zh'"
