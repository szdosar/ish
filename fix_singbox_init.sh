#!/bin/sh
# 修补 OpenWrt package/feeds/small/sing-box/files/sing-box.init
# - 自动备份（含时间戳）
# - 幂等：缺啥补啥，不重复添加
# - 追加标准 start()/stop() 接口

set -e

FILE="package/feeds/small/sing-box/files/sing-box.init"

# 颜色辅助
GREEN="$(printf '\033[32m')"
YELLOW="$(printf '\033[33m')"
RED="$(printf '\033[31m')"
NC="$(printf '\033[0m')"

err() { echo "${RED}[ERR]${NC} $*"; exit 1; }
info(){ echo "${GREEN}[OK ]${NC} $*"; }
warn(){ echo "${YELLOW}[WARN]${NC} $*"; }

[ -f "$FILE" ] || err "文件不存在：$FILE"

# 备份
TS="$(date +%Y%m%d%H%M%S)"
BACKUP="${FILE}.bak.${TS}"
cp -a "$FILE" "$BACKUP"
info "已备份到：$BACKUP"

# 确保文件结尾有换行
tail -c1 "$FILE" | od -An -t x1 | grep -q '0a' || echo >> "$FILE"

has_start_func() {
    grep -Eq '^[[:space:]]*start[[:space:]]*\(\)[[:space:]]*\{' "$FILE"
}
has_stop_func() {
    grep -Eq '^[[:space:]]*stop[[:space:]]*\(\)[[:space:]]*\{' "$FILE"
}

ADDED=0

if ! has_start_func; then
    warn "未检测到 start()，正在追加..."
    cat >> "$FILE" <<'EOF'

start() {
    start_service
}
EOF
    ADDED=1
else
    info "已检测到 start()，无需添加。"
fi

if ! has_stop_func; then
    warn "未检测到 stop()，正在追加..."
    cat >> "$FILE" <<'EOF'

stop() {
    stop_service
}
EOF
    ADDED=1
else
    info "已检测到 stop()，无需添加。"
fi

chmod +x "$FILE"

if [ "$ADDED" -eq 0 ]; then
    info "无需修改：已包含 start()/stop()。备份文件仍保留：$BACKUP"
else
    info "修补完成：已确保包含 start()/stop()。"
    echo "下一步示例："
    echo "  /etc/init.d/sing-box enable"
    echo "  /etc/init.d/sing-box start"
fi
