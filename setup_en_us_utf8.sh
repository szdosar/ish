#!/bin/sh
# Set en_US.UTF-8 as default locale on Debian 13+ (POSIX sh, ASCII only)
set -eu

TARGET_LOCALE="en_US.UTF-8"
LOCALE_GEN="/etc/locale.gen"
DEFAULT_LOCALE="/etc/default/locale"

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run as root (sudo -i or su -)."
  exit 1
fi

# 1) Ensure locales package
if ! dpkg -s locales >/dev/null 2>&1; then
  apt-get update -y
  DEBIAN_FRONTEND=noninteractive apt-get install -y locales
fi

# 2) Enable en_US.UTF-8 in /etc/locale.gen
[ -f "$LOCALE_GEN" ] || touch "$LOCALE_GEN"
cp -a "$LOCALE_GEN" "${LOCALE_GEN}.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

if grep -Eq '^[# ]*en_US\.UTF-8[[:space:]]+UTF-8' "$LOCALE_GEN"; then
  sed -i 's/^[# ]*en_US\.UTF-8[[:space:]]\+UTF-8/en_US.UTF-8 UTF-8/' "$LOCALE_GEN"
else
  printf '%s\n' 'en_US.UTF-8 UTF-8' >> "$LOCALE_GEN"
fi

# 3) Generate locales
locale-gen

# 4) Set default to en_US.UTF-8
update-locale LANG="$TARGET_LOCALE" LANGUAGE="en_US:en"

# 5) Remove permanent LC_ALL if present (avoid overriding)
if [ -f "$DEFAULT_LOCALE" ] && grep -q '^LC_ALL=' "$DEFAULT_LOCALE"; then
  cp -a "$DEFAULT_LOCALE" "${DEFAULT_LOCALE}.bak.$(date +%Y%m%d%H%M%S)"
  grep -v '^LC_ALL=' "$DEFAULT_LOCALE" > "${DEFAULT_LOCALE}.tmp"
  mv "${DEFAULT_LOCALE}.tmp" "$DEFAULT_LOCALE"
fi

echo "Done. Default locale set to: $TARGET_LOCALE"
echo "New login sessions will pick it up automatically."
echo "To apply immediately in current shell:"
echo "  export LANG=$TARGET_LOCALE LANGUAGE=en_US:en"
