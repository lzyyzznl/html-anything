#!/bin/bash
set -e

# RPM %post 脚本在 root 上下文中运行
# 需要检测实际的目标用户

# 获取目标用户 - 按优先级尝试
REAL_USER=""
HOME_DIR=""

# 1. 首先尝试 SUDO_USER
if [ -n "$SUDO_USER" ]; then
    REAL_USER="$SUDO_USER"
    HOME_DIR=$(getent passwd "$SUDO_USER" | cut -d: -f6)
fi

# 2. 如果不是 sudo 安装，尝试 logname
if [ -z "$REAL_USER" ]; then
    REAL_USER=$(logname 2>/dev/null || true)
    if [ -n "$REAL_USER" ]; then
        HOME_DIR=$(getent passwd "$REAL_USER" | cut -d: -f6)
    fi
fi

# 3. 尝试 /etc/passwd 中第一个普通用户（UID >= 1000）
if [ -z "$REAL_USER" ]; then
    REAL_USER=$(awk -F: '$3 >= 1000 && $3 < 65534 {print $1; exit}' /etc/passwd)
    if [ -n "$REAL_USER" ]; then
        HOME_DIR=$(getent passwd "$REAL_USER" | cut -d: -f6)
    fi
fi

# 4. 最后手段：使用 $USER 和 $HOME
if [ -z "$REAL_USER" ] || [ -z "$HOME_DIR" ]; then
    REAL_USER="${USER:-root}"
    HOME_DIR="${HOME:-/root}"
fi

# 验证 HOME_DIR 是否有效
if [ ! -d "$HOME_DIR" ]; then
    echo "警告：用户目录 $HOME_DIR 不存在"
    # 尝试使用 /home/$REAL_USER
    if [ -d "/home/$REAL_USER" ]; then
        HOME_DIR="/home/$REAL_USER"
        echo "使用 /home/$REAL_USER 作为家目录"
    else
        echo "错误：无法确定有效的用户目录"
        exit 1
    fi
fi

echo "安装到用户：$REAL_USER ($HOME_DIR)"

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
