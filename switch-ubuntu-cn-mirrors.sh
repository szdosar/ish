#!/usr/bin/env bash
# Switch Ubuntu APT mirrors to CN for Ubuntu 24.04+ (Deb822-aware)
# Author: dosar's helper
set -euo pipefail

# --- helper: sudo if not root ---
if [ "$(id -u)" -ne 0 ]; then SUDO="sudo"; else SUDO=""; fi

# --- detect codename ---
CODENAME="$(
  . /etc/os-release 2>/dev/null || true
  echo "${VERSION_CODENAME:-}"
)"
if [ -z "$CODENAME" ] && command -v lsb_release >/dev/null 2>&1; then
  CODENAME="$(lsb_release -sc)"
fi
if [ -z "$CODENAME" ]; then
  echo "无法识别系统版本代号（VERSION_CODENAME）。请确认系统为 Ubuntu，并安装 lsb-release。" >&2
  exit 1
fi

# --- ensure apt dirs exist ---
$SUDO install -d -m 0755 /etc/apt /etc/apt/sources.list.d /etc/apt/trusted.gpg.d

# --- known CN mirrors ---
declare -A MIRRORS=(
  ["aliyun"]="https://mirrors.aliyun.com/ubuntu"
  ["tuna"]="https://mirrors.tuna.tsinghua.edu.cn/ubuntu"
  ["ustc"]="https://mirrors.ustc.edu.cn/ubuntu"
  ["huawei"]="https://repo.huaweicloud.com/ubuntu"
  ["bfsu"]="https://mirrors.bfsu.edu.cn/ubuntu"
)
DEFAULT_ALIAS="aliyun"

# --- args ---
USE_DEB822=1           # 默认写 Deb822
DRYRUN=0
CHOSEN_URL=""
CHOSEN_ALIAS=""
FORCE=0

usage() {
  cat <<'USAGE'
用法：
  switch-ubuntu-cn-mirrors.sh [选项]

选项：
  -m ALIAS|URL   指定镜像（别名：aliyun|tuna|ustc|huawei|bfsu；或直接给完整URL）
  -l             列出已内置的镜像别名
  -s             使用传统 sources.list 而非 Deb822
  -n             仅演示（dry-run），不真正改动
  -f             不提示直接执行（非交互）
  -h             显示本帮助

示例：
  ./switch-ubuntu-cn-mirrors.sh
  ./switch-ubuntu-cn-mirrors.sh -m tuna
  ./switch-ubuntu-cn-mirrors.sh -m https://mirrors.ustc.edu.cn/ubuntu -s -f
USAGE
}

while getopts ":m:lsnfh" opt; do
  case "$opt" in
    m)
      if [[ -n "${MIRRORS[$OPTARG]:-}" ]]; then
        CHOSEN_ALIAS="$OPTARG"
        CHOSEN_URL="${MIRRORS[$OPTARG]}"
      else
        CHOSEN_URL="$OPTARG"   # treat as URL
      fi
      ;;
    l) printf "可用别名："; printf "%s " "${!MIRRORS[@]}"; echo; exit 0 ;;
    s) USE_DEB822=0 ;;
    n) DRYRUN=1 ;;
    f) FORCE=1 ;;
    h) usage; exit 0 ;;
    \?) usage; exit 1 ;;
  esac
done

# --- interactive choose mirror if not provided ---
if [ -z "$CHOSEN_URL" ]; then
  if [ "$FORCE" -eq 1 ]; then
    CHOSEN_ALIAS="$DEFAULT_ALIAS"
    CHOSEN_URL="${MIRRORS[$DEFAULT_ALIAS]}"
  else
    echo "选择一个国内镜像："
    i=1; declare -a KEYS
    for k in "${!MIRRORS[@]}"; do
      KEYS[$i]="$k"
      echo "  $i) $k  -> ${MIRRORS[$k]}"
      i=$((i+1))
    done
    read -rp "输入序号（默认 ${DEFAULT_ALIAS}）: " idx
    if [[ -z "${idx:-}" ]]; then
      CHOSEN_ALIAS="$DEFAULT_ALIAS"; CHOSEN_URL="${MIRRORS[$DEFAULT_ALIAS]}"
    else
      if ! [[ "$idx" =~ ^[0-9]+$ ]] || [ -z "${KEYS[$idx]:-}" ]; then
        echo "无效选择，使用默认：$DEFAULT_ALIAS"
        CHOSEN_ALIAS="$DEFAULT_ALIAS"; CHOSEN_URL="${MIRRORS[$DEFAULT_ALIAS]}"
      else
        CHOSEN_ALIAS="${KEYS[$idx]}"; CHOSEN_URL="${MIRRORS[$CHOSEN_ALIAS]}"
      fi
    fi
  fi
fi

echo "系统代号：$CODENAME"
echo "目标镜像：${CHOSEN_ALIAS:-custom} -> $CHOSEN_URL"
echo "使用格式：$([ $USE_DEB822 -eq 1 ] && echo Deb822 || echo sources.list)"
[ $DRYRUN -eq 1 ] && echo "[DRY-RUN] 仅演示，不会改动文件。"

TS="$(date +%F-%H%M%S)"
BACKUP_DIR="/etc/apt/backup-$TS"
echo "备份目录：$BACKUP_DIR"
[ $DRYRUN -eq 0 ] && $SUDO install -d -m 0755 "$BACKUP_DIR"

backup_file() {
  local f="$1"
  [ -e "$f" ] || return 0
  echo "备份 $f -> $BACKUP_DIR"
  [ $DRYRUN -eq 0 ] && $SUDO cp -a "$f" "$BACKUP_DIR/"
}

# 备份现有配置
backup_file /etc/apt/sources.list
for f in /etc/apt/sources.list.d/*; do
  [ -e "$f" ] && backup_file "$f"
done

# 禁用默认 Deb822（避免和 CN 源混用）
if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
  echo "禁用默认 ubuntu.sources"
  if [ $DRYRUN -eq 0 ]; then
    $SUDO mv /etc/apt/sources.list.d/ubuntu.sources "/etc/apt/sources.list.d/ubuntu.sources.disabled.$TS"
  fi
fi

if [ $USE_DEB822 -eq 1 ]; then
  echo "写入 Deb822 源：/etc/apt/sources.list.d/ubuntu-cn.sources"
  Deb822_CONTENT=$(
    cat <<EOF
Types: deb
URIs: $CHOSEN_URL
Suites: $CODENAME $CODENAME-updates $CODENAME-backports $CODENAME-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
  )
  echo "$Deb822_CONTENT"
  if [ $DRYRUN -eq 0 ]; then
    echo "$Deb822_CONTENT" | $SUDO tee /etc/apt/sources.list.d/ubuntu-cn.sources >/dev/null
    # 移除 sources.list，避免重复
    [ -f /etc/apt/sources.list ] && $SUDO rm -f /etc/apt/sources.list
  fi
else
  echo "写入传统源：/etc/apt/sources.list"
  LIST_CONTENT=$(
    cat <<EOF
deb $CHOSEN_URL $CODENAME main restricted universe multiverse
deb $CHOSEN_URL $CODENAME-updates main restricted universe multiverse
deb $CHOSEN_URL $CODENAME-backports main restricted universe multiverse
deb $CHOSEN_URL $CODENAME-security main restricted universe multiverse
EOF
  )
  echo "$LIST_CONTENT"
  if [ $DRYRUN -eq 0 ]; then
    echo "$LIST_CONTENT" | $SUDO tee /etc/apt/sources.list >/dev/null
    # （可选）移除可能残留的 CN 以外 Deb822
    if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
      $SUDO mv /etc/apt/sources.list.d/ubuntu.sources "/etc/apt/sources.list.d/ubuntu.sources.disabled.$TS"
    fi
  fi
fi

# 清理并更新
echo "清理缓存并更新索引..."
if [ $DRYRUN -eq 0 ]; then
  $SUDO apt-get clean
  $SUDO rm -rf /var/lib/apt/lists/*
  $SUDO apt-get update
fi

# 校验输出
echo
echo "=== 校验是否仍存在 SG 或默认全球镜像条目 ==="
if [ $DRYRUN -eq 0 ]; then
  if grep -R "sg.archive\|archive.ubuntu.com\|security.ubuntu.com" -n /etc/apt; then
    echo "⚠️ 仍有非 CN 源文件，请按输出逐个检查并禁用/改为 CN。"
  else
    echo "✅ OK：未发现 SG 或默认全球镜像残留。"
  fi
else
  echo "[DRY-RUN] 省略实际校验。"
fi

echo
echo "备份已存放在：$BACKUP_DIR"
echo "完成。"
