#!/bin/sh
# Switch default locale between en_US.UTF-8 and zh_CN.UTF-8 on Debian 13+
# POSIX sh, ASCII only, idempotent.

set -eu

LOCALE_GEN="/etc/locale.gen"
DEFAULT_LOCALE="/etc/default/locale"

usage() {
  cat <<'EOF'
Usage:
  switch_locale.sh --en      # set default to en_US.UTF-8
  switch_locale.sh --zh      # set default to zh_CN.UTF-8
  switch_locale.sh --show    # show current locale and /etc/default/locale

Notes:
  - Run as root (sudo -i or su -).
  - New login sessions pick changes automatically.
  - To apply immediately in current shell, export LANG / LANGUAGE manually.
EOF
}

need_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root (sudo -i or su -)."
    exit 1
  fi
}

ensure_locales_pkg() {
  if ! dpkg -s locales >/dev/null 2>&1; then
    apt-get update -y
    DEBIAN_FRONTEND=noninteractive apt-get install -y locales
  fi
}

backup_once() {
  f="$1"
  [ -f "$f" ] || return 0
  # create one backup per run
  [ -n "${_BACKED_UP:-}" ] || _BACKED_UP="$(date +%Y%m%d%H%M%S)"
  cp -a "$f" "$f.bak.${_BACKED_UP}" 2>/dev/null || true
}

enable_in_locale_gen() {
  # $1: locale code like en_US.UTF-8
  [ -f "$LOCALE_GEN" ] || touch "$LOCALE_GEN"
  backup_once "$LOCALE_GEN"
  lc="$1"
  # uncomment if present; otherwise append
  if grep -Eq "^[# ]*$(printf '%s' "$lc" | sed 's/[].[^$*/]/\\&/g')[[:space:]]+UTF-8" "$LOCALE_GEN"; then
    sed -i "s|^[# ]*${lc}[[:space:]]\\+UTF-8|${lc} UTF-8|" "$LOCALE_GEN"
  else
    printf '%s\n' "${lc} UTF-8" >> "$LOCALE_GEN"
  fi
}

generate_locales() {
  locale-gen
}

set_default_locale() {
  # $1: LANG value; $2: LANGUAGE value
  lang="$1"
  language="$2"
  update-locale LANG="$lang" LANGUAGE="$language"

  # remove permanent LC_ALL to avoid overriding LANG/LANGUAGE
  if [ -f "$DEFAULT_LOCALE" ] && grep -q '^LC_ALL=' "$DEFAULT_LOCALE"; then
    backup_once "$DEFAULT_LOCALE"
    grep -v '^LC_ALL=' "$DEFAULT_LOCALE" > "${DEFAULT_LOCALE}.tmp"
    mv "${DEFAULT_LOCALE}.tmp" "$DEFAULT_LOCALE"
  fi
}

show_status() {
  echo "---- locale (current shell) ----"
  locale || true
  echo
  echo "---- /etc/default/locale ----"
  if [ -f "$DEFAULT_LOCALE" ]; then
    cat "$DEFAULT_LOCALE"
  else
    echo "(not found)"
  fi
}

do_en() {
  need_root
  ensure_locales_pkg
  enable_in_locale_gen "en_US.UTF-8"
  generate_locales
  set_default_locale "en_US.UTF-8" "en_US:en"
  echo "Default locale set to en_US.UTF-8."
  echo "New login sessions will use it. For current shell:"
  echo "  export LANG=en_US.UTF-8 LANGUAGE='en_US:en'"
}

do_zh() {
  need_root
  ensure_locales_pkg
  enable_in_locale_gen "zh_CN.UTF-8"
  generate_locales
  set_default_locale "zh_CN.UTF-8" "zh_CN:zh:en_US:en"
  echo "Default locale set to zh_CN.UTF-8."
  echo "New login sessions will use it. For current shell:"
  echo "  export LANG=zh_CN.UTF-8 LANGUAGE='zh_CN:zh:en_US:en'"
}

case "${1:-}" in
  --en)  do_en ;;
  --zh)  do_zh ;;
  --show) show_status ;;
  *) usage; exit 1 ;;
esac
