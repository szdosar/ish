#!/bin/sh
# 修补 OpenWrt package/feeds/small/sing-box/files/sing-box.init
# - 自动备份（含时间戳）
# - 幂等：缺啥补啥，不重复添加
# - 仅追加标准 start()/stop() 接口，保持原有 procd 逻辑不变

set -e

FILE="package/feeds/small/sing-box/files/sing-box.init"

# 颜色辅助（若终端不支持也不会出错）
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

# 确保文件结尾有换行，避免粘在最后一行后面
# shellcheck disable=SC1003
tail -c1 "$FILE" | od -An -t x1 | grep -q '0a' || echo >> "$FILE"

has_start_func() {
    # 匹配：start() { 或带空格缩进等情况
    grep -Eq '^[[:space:]]*start[[:space:]]*\(\)[[:space:]]*\{' "$FILE"
}
has_stop_func() {
    grep -Eq '^[[:space:]]*stop[[:space:]]*\(\)[[:space:]]*\{' "$FILE"
}

ADDED=0

if ! has_start_func; then
    warn "未检测到 start()，正在追加..."
    cat >> "$FILE" <<'EOF'

# Added by fix_singbox_init.sh to expose rc.common entry for LuCI
start() {
    # 调用 procd 的入口（若原脚本已定义 start_service）
    if command -v start_service >/dev/null 2>&1; then
        start_service
    else
        # 兜底：尝试直接调用 /usr/bin/sing-box（如有需要可按你环境调整）
        [ -x /usr/bin/sing-box ] && /usr/bin/sing-box -h >/dev/null 2>&1 || true
    fi
}
EOF
    ADDED=1
else
    info "已检测到 start()，无需添加。"
fi

if ! has_stop_func; then
    warn "未检测到 stop()，正在追加..."
    cat >> "$FILE" <<'EOF'

# Added by fix_singbox_init.sh to expose rc.common entry for LuCI
stop() {
    # 调用 procd 的入口（若原脚本已定义 stop_service）
    if command -v stop_service >/dev/null 2>&1; then
        stop_service
    else
        # 兜底：尝试优雅终止 sing-box 进程（按需调整）
        if command -v service_stop >/dev/null 2>&1; then
            service_stop /usr/bin/sing-box
        else
            pkill -TERM -x sing-box >/dev/null 2>&1 || true
        fi
    fi
}
EOF
    ADDED=1
else
    info "已检测到 stop()，无需添加。"
fi

# 确保脚本可执行
chmod +x "$FILE"

if [ "$ADDED" -eq 0 ]; then
    info "无需修改：已包含 start()/stop()。备份文件仍保留：$BACKUP"
else
    info "修补完成：已确保包含 start()/stop()。"
    echo "下一步（示例）："
    echo "  /etc/init.d/sing-box enable"
    echo "  /etc/init.d/sing-box start"
fi
