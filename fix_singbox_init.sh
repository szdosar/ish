#!/bin/sh
# 修补 OpenWrt package/feeds/small/sing-box/files/sing-box.init
# - 自动备份（含时间戳）
# - 检测/添加 start()/stop()
# - 检测 START=99 / USE_PROCD=1 位置，必要时挪到第2、3行

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

# 读取前 12 行检查 START / USE_PROCD
HEAD12="$(head -n 12 "$FILE")"
NEED_MOVE=0
NEED_START=0
NEED_USEPROCD=0

echo "$HEAD12" | grep -q "^START=99"     || NEED_START=1
echo "$HEAD12" | grep -q "^USE_PROCD=1"  || NEED_USEPROCD=1

# 如果文件中根本没有 START=99 或 USE_PROCD=1，也需要补齐
grep -q "^START=99" "$FILE"    || NEED_START=1
grep -q "^USE_PROCD=1" "$FILE" || NEED_USEPROCD=1

# 检查它们是否都在前12行
if ! (echo "$HEAD12" | grep -q "^START=99" && echo "$HEAD12" | grep -q "^USE_PROCD=1"); then
    NEED_MOVE=1
fi

if [ "$NEED_MOVE" -eq 1 ] || [ "$NEED_START" -eq 1 ] || [ "$NEED_USEPROCD" -eq 1 ]; then
    warn "调整 START=99 / USE_PROCD=1 位置..."
    # 删除原位置
    sed -i '/^START=99$/d' "$FILE"
    sed -i '/^USE_PROCD=1$/d' "$FILE"
    # 在 #!/bin/sh /etc/rc.common 后插入
    awk -v add_start="$NEED_START" -v add_use="$NEED_USEPROCD" '
        NR==1 {
            print $0
            print "START=99"
            print "USE_PROCD=1"
            next
        }
        { print }
    ' "$FILE" > "${FILE}.tmp" && mv "${FILE}.tmp" "$FILE"
    info "已将 START=99 / USE_PROCD=1 放到文件第2、3行。"
else
    info "START=99 / USE_PROCD=1 已在前 12 行内，无需调整。"
fi

# 确保文件结尾有换行
tail -c1 "$FILE" | od -An -t x1 | grep -q '0a' || echo >> "$FILE"

# 检查 start()/stop()
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
