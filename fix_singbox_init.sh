#!/bin/sh
# 扫描并修补所有 sing-box.init
# - 必须在 OpenWrt 源码根目录执行
# - find 查找所有 sing-box.init（排除 build_dir/、bin/ 等）
# - 备份、调整 START=99/USE_PROCD=1 到第2/3行（如不在前12行或缺失）
# - 追加标准 start()/stop()（如缺失）

set -e

# 彩色输出
GREEN="$(printf '\033[32m')"
YELLOW="$(printf '\033[33m')"
RED="$(printf '\033[31m')"
NC="$(printf '\033[0m')"

ok()  { echo "${GREEN}[OK ]${NC} $*"; }
warn(){ echo "${YELLOW}[WARN]${NC} $*"; }
err() { echo "${RED}[ERR]${NC} $*"; exit 1; }

# 1) 基础检查：OpenWrt 源码根目录
[ -f "include/toplevel.mk" ] || err "未检测到 include/toplevel.mk，请在 OpenWrt 源码根目录执行。"
[ -x "scripts/feeds" ]       || err "未检测到 scripts/feeds，请在 OpenWrt 源码根目录执行。"
ok "已确认在 OpenWrt 源码根目录。"

TS="$(date +%Y%m%d%H%M%S)"

# 2) find 所有 sing-box.init（排除常见输出目录）
FILES="$(find . \
  -path './build_dir' -prune -o \
  -path './bin'       -prune -o \
  -type f -name 'sing-box.init' -print)"

[ -n "$FILES" ] || err "未找到任何 sing-box.init 文件。"

for FILE in $FILES; do
  echo "——— 处理: $FILE"

  [ -f "$FILE" ] || { warn "跳过（不存在）：$FILE"; continue; }

  # 备份
  BACKUP="${FILE}.bak.${TS}"
  cp -a "$FILE" "$BACKUP"
  ok "已备份到：$BACKUP"

  # 确保文件结尾有换行
  tail -c1 "$FILE" 2>/dev/null | od -An -t x1 | grep -q '0a' || echo >> "$FILE"

  # 检查前12行
  HEAD12="$(head -n 12 "$FILE" || true)"
  IN_HEAD_START=0
  IN_HEAD_USE=0

  echo "$HEAD12" | grep -q "^START=99"    && IN_HEAD_START=1
  echo "$HEAD12" | grep -q "^USE_PROCD=1" && IN_HEAD_USE=1

  NEED_MOVE=0
  [ $IN_HEAD_START -eq 1 ] && [ $IN_HEAD_USE -eq 1 ] || NEED_MOVE=1

  # 如果需要移动/补齐 START / USE_PROCD
  if [ $NEED_MOVE -eq 1 ]; then
    warn "调整 START=99 / USE_PROCD=1 到文件第2、3行..."

    # 删除任意 START= / USE_PROCD= 定义（避免重复）
    sed -i '/^START=/d' "$FILE"
    sed -i '/^USE_PROCD=/d' "$FILE"

    # 将两行插在第1行后
    awk '
      NR==1 {
        print $0
        print "START=99"
        print "USE_PROCD=1"
        next
      }
      { print }
    ' "$FILE" > "${FILE}.tmp" && mv "${FILE}.tmp" "$FILE"

    ok "已放置 START=99 / USE_PROCD=1 到第2、3行。"
  else
    ok "START=99 / USE_PROCD=1 已在前12行，无需调整。"
  fi

  # 检查 start()/stop() 是否存在
  HAS_START=0
  HAS_STOP=0
  grep -Eq '^[[:space:]]*start[[:space:]]*\(\)[[:space:]]*\{' "$FILE" && HAS_START=1
  grep -Eq '^[[:space:]]*stop[[:space:]]*\(\)[[:space:]]*\{'  "$FILE" && HAS_STOP=1

  ADDED=0

  if [ $HAS_START -eq 0 ]; then
    warn "追加 start()..."
    cat >> "$FILE" <<'EOF'

start() {
    start_service
}
EOF
    ADDED=1
  else
    ok "已检测到 start()，无需添加。"
  fi

  if [ $HAS_STOP -eq 0 ]; then
    warn "追加 stop()..."
    cat >> "$FILE" <<'EOF'

stop() {
    stop_service
}
EOF
    ADDED=1
  else
    ok "已检测到 stop()，无需添加。"
  fi

  chmod +x "$FILE"

  if [ $ADDED -eq 0 ] && [ $NEED_MOVE -eq 0 ]; then
    ok "该文件无需修改：$FILE（备份保留：$BACKUP）"
  else
    ok "修补完成：$FILE"
  fi

done

ok "全部处理完成。可执行：/etc/init.d/sing-box enable && /etc/init.d/sing-box start"
