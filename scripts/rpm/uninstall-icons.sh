#!/bin/bash
set -e

# 获取当前用户
if [ -n "$SUDO_USER" ]; then
    REAL_USER="$SUDO_USER"
    HOME_DIR=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
    REAL_USER="$USER"
    HOME_DIR="$HOME"
fi

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
