#!/usr/bin/env bash
# 固定英文标准目录 + 清理残留中文书签（Debian/Ubuntu GNOME）
# 用法：
#   bash fix_xdg_user_dirs_bookmarks.sh           # 合并中文目录内容到英文目录（若存在）
#   bash fix_xdg_user_dirs_bookmarks.sh --no-merge  # 不做内容合并

set -euo pipefail

MERGE_CONTENT="yes"
if [[ "${1:-}" == "--no-merge" ]]; then
  MERGE_CONTENT="no"
fi

# 1) 目标英文目录映射
declare -A MAP=(
  [DESKTOP]="Desktop"
  [DOWNLOAD]="Downloads"
  [DOCUMENTS]="Documents"
  [PICTURES]="Pictures"
  [MUSIC]="Music"
  [VIDEOS]="Videos"
  [TEMPLATES]="Templates"
  [PUBLICSHARE]="Public"
)

# 2) 可能存在的中文目录名（用于合并与书签清理）
declare -A CN=(
  [DESKTOP]="桌面"
  [DOWNLOAD]="下载"
  [DOCUMENTS]="文档"
  [PICTURES]="图片"
  [MUSIC]="音乐"
  [VIDEOS]="视频"
  [TEMPLATES]="模板"
  [PUBLICSHARE]="公共"
)

mkdir -p "$HOME/.config"

echo "==> 写入 ~/.config/user-dirs.dirs（英文映射）"
{
  echo '# Format is XDG_xxx_DIR="$HOME/yyy"'
  for key in "${!MAP[@]}"; do
    echo "XDG_${key}_DIR=\"\$HOME/${MAP[$key]}\""
  done | sort  # 仅为观感整齐
} > "$HOME/.config/user-dirs.dirs"

echo "==> 创建英文目录（不存在则创建）"
for key in "${!MAP[@]}"; do
  d="$HOME/${MAP[$key]}"
  mkdir -p "$d"
done

# 3) 合并中文目录内容到英文目录（若存在）
if [[ "$MERGE_CONTENT" == "yes" ]]; then
  echo "==> 合并中文目录内容到英文目录（若存在）"
  has_rsync="no"
  command -v rsync >/dev/null 2>&1 && has_rsync="yes"

  for key in "${!CN[@]}"; do
    src="$HOME/${CN[$key]}"
    dst="$HOME/${MAP[$key]}"
    if [[ -d "$src" && "$src" != "$dst" ]]; then
      echo "   - $src  ->  $dst"
      if [[ "$has_rsync" == "yes" ]]; then
        rsync -a "$src"/ "$dst"/ 2>/dev/null || true
      else
        # rsync 不在时，用 cp -a 近似替代
        shopt -s dotglob nullglob
        cp -a "$src"/. "$dst"/ 2>/dev/null || true
        shopt -u dotglob nullglob || true
      fi
      # 尝试删除空的中文目录
      rmdir "$src" 2>/dev/null || true
    fi
  done
else
  echo "==> 跳过合并内容（--no-merge）"
fi

# 4) 关闭自动提示；并标记 locale（避免再提示）
echo "==> 关闭自动提示重命名"
printf 'enabled=False\n' > "$HOME/.config/user-dirs.conf"
printf 'en_US.UTF-8\n' > "$HOME/.config/user-dirs.locale"

# 5) 清空 GTK 书签（备份后删除）
echo "==> 备份并清空 GTK 书签"
for f in "$HOME/.config/gtk-3.0/bookmarks" "$HOME/.config/gtk-4.0/bookmarks" "$HOME/.gtk-bookmarks"; do
  if [[ -f "$f" ]]; then
    cp -a "$f" "$f.bak.$(date +%s)"
    rm -f "$f"
  fi
done

# 6) 重新添加英文目录为书签（可选但实用）
if command -v gio >/dev/null 2>&1; then
  echo "==> 添加英文目录为书签"
  for key in DESKTOP DOWNLOAD DOCUMENTS PICTURES MUSIC VIDEOS TEMPLATES PUBLICSHARE; do
    p="$HOME/${MAP[$key]}"
    [[ -d "$p" ]] && gio bookmark add "file://$p" 2>/dev/null || true
  done
fi

# 7) 重启 Nautilus（若存在）
if command -v nautilus >/dev/null 2>&1; then
  echo "==> 重启 Nautilus"
  nautilus -q || true
  (nautilus &>/dev/null & disown) || true
fi

echo "==> 完成。当前映射："
grep XDG_ "$HOME/.config/user-dirs.dirs" | sed "s|$HOME|~|g"
echo "提示：如侧栏仍未更新，注销并重新登录一次桌面会更稳妥。"
