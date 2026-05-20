#!/bin/bash
set -e

# RPM %post 脚本在 root 上下文中运行
# 需要检测实际的目标用户

# 获取当前用户（如果是 rpm 安装，可能是 root）
if [ -n "$SUDO_USER" ]; then
    REAL_USER="$SUDO_USER"
    HOME_DIR=$(getent passwd "$SUDO_USER" | cut -d: -f6)
elif [ "$USER" != "root" ]; then
    REAL_USER="$USER"
    HOME_DIR="$HOME"
else
    # RPM 安装时，尝试从环境获取或默认使用第一个普通用户
    # 在大多数桌面环境中，使用实际登录用户
    LOGIN_USER=$(who am i 2>/dev/null | awk '{print $1}' || true)
    if [ -n "$LOGIN_USER" ]; then
        REAL_USER="$LOGIN_USER"
        HOME_DIR=$(getent passwd "$LOGIN_USER" | cut -d: -f6)
    else
        # 回退：使用当前用户（可能是 root）
        REAL_USER="$USER"
        HOME_DIR="$HOME"
    fi
fi

# 验证 HOME_DIR 是否存在
if [ ! -d "$HOME_DIR" ]; then
    echo "警告：用户目录 $HOME_DIR 不存在，尝试创建..."
    mkdir -p "$HOME_DIR"
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
