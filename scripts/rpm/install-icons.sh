#!/bin/bash
set -e

# RPM %post 脚本在 root 上下文中运行
# 目标用户由 spec 文件的 %post 段设置

# 获取目标用户 - 优先使用 spec 传递的环境变量
REAL_USER=""
HOME_DIR=""

# 1. 优先使用 RPM spec 传递的变量
if [ -n "$REAL_USER" ] && [ -n "$HOME_DIR" ]; then
    echo "使用 RPM spec 传递的用户信息：$REAL_USER ($HOME_DIR)"
# 2. 尝试 TARGET_USER 变量
elif [ -n "$TARGET_USER" ]; then
    REAL_USER="$TARGET_USER"
    HOME_DIR=$(getent passwd "$TARGET_USER" | cut -d: -f6)
    echo "使用 TARGET_USER: $REAL_USER ($HOME_DIR)"
# 3. 尝试 SUDO_USER
elif [ -n "$SUDO_USER" ]; then
    REAL_USER="$SUDO_USER"
    HOME_DIR=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    echo "使用 SUDO_USER: $REAL_USER ($HOME_DIR)"
# 4. 尝试 logname
else
    REAL_USER=$(logname 2>/dev/null || true)
    if [ -n "$REAL_USER" ]; then
        HOME_DIR=$(getent passwd "$REAL_USER" | cut -d: -f6)
        echo "使用 logname: $REAL_USER ($HOME_DIR)"
    fi
fi

# 5. 最后手段：使用 /etc/passwd 中第一个普通用户
if [ -z "$REAL_USER" ] || [ -z "$HOME_DIR" ]; then
    REAL_USER=$(awk -F: '$3 >= 1000 && $3 < 65534 {print $1; exit}' /etc/passwd)
    if [ -n "$REAL_USER" ]; then
        HOME_DIR=$(getent passwd "$REAL_USER" | cut -d: -f6)
        echo "使用 /etc/passwd 第一个用户：$REAL_USER ($HOME_DIR)"
    fi
fi

# 6. 最终回退
if [ -z "$REAL_USER" ] || [ -z "$HOME_DIR" ]; then
    echo "错误：无法确定目标用户"
    exit 1
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
