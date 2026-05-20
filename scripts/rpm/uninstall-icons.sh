#!/bin/bash
set -e

# 从 /etc/passwd 获取用户家目录的函数
get_home_dir() {
    local user=$1
    local home
    home=$(getent passwd "$user" 2>/dev/null | cut -d: -f6)
    if [ -z "$home" ]; then
        home=$(awk -F: -v u="$user" '$1 == u {print $6; exit}' /etc/passwd)
    fi
    echo "$home"
}

# 获取当前用户 - 与 install-icons.sh 相同的逻辑
REAL_USER=""
HOME_DIR=""

# 1. 尝试 SUDO_USER
if [ -n "$SUDO_USER" ]; then
    REAL_USER="$SUDO_USER"
    HOME_DIR=$(get_home_dir "$SUDO_USER")
# 2. 尝试 logname
elif [ "$(logname 2>/dev/null || true)" != "root" ]; then
    REAL_USER=$(logname 2>/dev/null || true)
    if [ -n "$REAL_USER" ]; then
        HOME_DIR=$(get_home_dir "$REAL_USER")
    fi
fi

# 3. 使用 /etc/passwd 中第一个普通用户
if [ -z "$REAL_USER" ]; then
    REAL_USER=$(awk -F: '$3 >= 1000 && $3 < 65534 {print $1; exit}' /etc/passwd)
    if [ -n "$REAL_USER" ]; then
        HOME_DIR=$(get_home_dir "$REAL_USER")
    fi
fi

# 4. 回退
if [ -z "$REAL_USER" ] || [ -z "$HOME_DIR" ]; then
    REAL_USER="${USER:-root}"
    HOME_DIR="${HOME:-/root}"
fi

echo "从用户 $REAL_USER ($HOME_DIR) 卸载..."

# 停止服务
systemctl --user stop html-anything.service 2>/dev/null || true
systemctl --user disable html-anything.service 2>/dev/null || true

# 删除 systemd 服务文件
rm -f "$HOME_DIR/.config/systemd/user/html-anything.service"

# 删除应用菜单项
rm -f "$HOME_DIR/.local/share/applications/html-anything.desktop"

# 删除桌面快捷方式
rm -f "$HOME_DIR/Desktop/html-anything.desktop"

# 删除图标
rm -f "$HOME_DIR/.local/share/icons/hicolor/scalable/apps/html-anything.svg"

# 更新图标缓存
gtk-update-icon-cache -f "$HOME_DIR/.local/share/icons/hicolor" 2>/dev/null || true

# 重新加载 systemd
systemctl --user daemon-reload 2>/dev/null || true

# 注意：保留用户数据目录 ~/.local/share/html-anything/
echo "卸载完成！"
echo "  - 已删除桌面快捷方式和应用菜单项"
echo "  - 用户数据已保留在：$HOME_DIR/.local/share/html-anything/"
