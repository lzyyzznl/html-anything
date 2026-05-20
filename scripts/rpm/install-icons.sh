#!/bin/bash
set -e

# 获取当前用户（如果是 rpm 安装，可能是 root）
if [ -n "$SUDO_USER" ]; then
    REAL_USER="$SUDO_USER"
    HOME_DIR=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
    REAL_USER="$USER"
    HOME_DIR="$HOME"
fi

# 创建用户数据目录
mkdir -p "$HOME_DIR/.local/share/html-anything"

# 复制 systemd 服务文件
mkdir -p "$HOME_DIR/.config/systemd/user"
cp /opt/html-anything/html-anything.service "$HOME_DIR/.config/systemd/user/"

# 复制桌面快捷方式到应用菜单
mkdir -p "$HOME_DIR/.local/share/applications"
cp /opt/html-anything/html-anything.desktop "$HOME_DIR/.local/share/applications/"

# 复制图标
mkdir -p "$HOME_DIR/.local/share/icons/hicolor/scalable/apps"
cp /opt/html-anything/server/public/icon.svg "$HOME_DIR/.local/share/icons/hicolor/scalable/apps/html-anything.svg"

# 复制桌面快捷方式到桌面（如果存在桌面目录）
if [ -d "$HOME_DIR/Desktop" ]; then
    cp /opt/html-anything/html-anything.desktop "$HOME_DIR/Desktop/html-anything.desktop"
    chmod +x "$HOME_DIR/Desktop/html-anything.desktop"
fi

# 更新图标缓存
gtk-update-icon-cache -f "$HOME_DIR/.local/share/icons/hicolor" 2>/dev/null || true

# 设置正确的文件权限
chown -R "$REAL_USER:" "$HOME_DIR/.local/share/html-anything"
chown -R "$REAL_USER:" "$HOME_DIR/.config/systemd/user/html-anything.service"
chown -R "$REAL_USER:" "$HOME_DIR/.local/share/applications/html-anything.desktop"
chown -R "$REAL_USER:" "$HOME_DIR/Desktop/html-anything.desktop" 2>/dev/null || true

# 以目标用户身份重新加载 systemd 并启用服务
# 注意：必须在用户会话上下文中执行
if command -v systemd-run >/dev/null 2>&1; then
    # 使用 systemd-run 以用户身份执行
    systemd-run --machine="${REAL_USER}@.host" --user systemctl daemon-reload 2>/dev/null || true
    systemd-run --machine="${REAL_USER}@.host" --user systemctl enable html-anything.service 2>/dev/null || true
else
    # 降级方案：尝试使用 su
    if command -v su >/dev/null 2>&1; then
        su - "$REAL_USER" -c "systemctl --user daemon-reload" 2>/dev/null || true
        su - "$REAL_USER" -c "systemctl --user enable html-anything.service" 2>/dev/null || true
    fi
fi

echo "安装完成！"
echo "  - 应用菜单项已创建"
echo "  - 桌面快捷方式已创建"
echo "  - 可通过桌面图标或应用菜单启动"
echo ""
echo "注意：systemd 服务已安装。首次启动时，请运行："
echo "  systemctl --user start html-anything.service"
echo "或直接点击桌面快捷方式启动应用。"
