# RPM Packaging Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 html-anything Next.js 应用打包为 RPM 包，支持桌面图标启动和智能进程管理

**Architecture:** 预构建模式打包 Next.js 应用，使用 systemd 用户服务管理进程，通过启动脚本实现智能检测（端口占用时直接打开浏览器，否则先启动应用）

**Tech Stack:** RPM spec, bash scripts, systemd user service, Next.js 16, pnpm

---

## File Structure

**Files to Create:**
- `scripts/rpm/html-anything.spec` - RPM spec 文件
- `scripts/rpm/start.sh` - 启动脚本（检测端口 + 启动/打开浏览器）
- `scripts/rpm/stop.sh` - 停止脚本（杀端口进程）
- `scripts/rpm/html-anything.service` - systemd 用户服务模板
- `scripts/rpm/html-anything.desktop` - 桌面快捷方式模板
- `scripts/rpm/install-icons.sh` - 安装后脚本（创建图标和快捷方式）
- `scripts/rpm/uninstall-icons.sh` - 卸载前脚本（删除图标）
- `next/public/icon.svg` - 应用图标

**Files to Modify:**
- `next/next.config.ts` - 添加 output: 'standalone' 配置（可选，用于精简打包）

---

### Task 1: 创建应用图标

**Files:**
- Create: `next/public/icon.svg`

- [ ] **Step 1: 创建 SVG 图标**

```svg
<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
  <defs>
    <linearGradient id="grad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#FF6B6B;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#4ECDC4;stop-opacity:1" />
    </linearGradient>
  </defs>
  <rect width="256" height="256" rx="40" fill="url(#grad)"/>
  <text x="128" y="180" font-family="Arial, sans-serif" font-size="120" font-weight="bold" fill="white" text-anchor="middle">&lt;/&gt;</text>
</svg>
```

- [ ] **Step 2: 验证图标文件存在**

```bash
ls -la next/public/icon.svg
```
Expected: file exists with ~500 bytes

---

### Task 2: 创建启动脚本

**Files:**
- Create: `scripts/rpm/start.sh`

- [ ] **Step 1: 创建启动脚本**

```bash
#!/bin/bash
set -e

PORT=48921
APP_DIR="/opt/html-anything/server"
DATA_DIR="$HOME/.local/share/html-anything"
PID_FILE="$DATA_DIR/html-anything.pid"
LOG_FILE="$DATA_DIR/html-anything.log"

# 确保数据目录存在
mkdir -p "$DATA_DIR"

# 检测端口是否被占用
if lsof -ti:$PORT > /dev/null 2>&1; then
    echo "应用已在端口 $PORT 运行"
    # 直接打开浏览器
    xdg-open "http://localhost:$PORT" &
    exit 0
fi

# 启动应用
cd "$APP_DIR"
export PORT=$PORT
export NODE_ENV=production

# 后台启动 Next.js
nohup pnpm start > "$LOG_FILE" 2>&1 &
echo $! > "$PID_FILE"

echo "正在启动应用..."
sleep 2

# 等待应用就绪
for i in {1..30}; do
    if curl -s "http://localhost:$PORT" > /dev/null 2>&1; then
        echo "应用已启动在端口 $PORT"
        xdg-open "http://localhost:$PORT" &
        exit 0
    fi
    sleep 1
done

echo "警告：应用启动超时，请查看日志：$LOG_FILE"
exit 1
```

- [ ] **Step 2: 设置执行权限**

```bash
chmod +x scripts/rpm/start.sh
```

- [ ] **Step 3: 验证脚本语法**

```bash
bash -n scripts/rpm/start.sh && echo "Syntax OK"
```
Expected: "Syntax OK"

---

### Task 3: 创建停止脚本

**Files:**
- Create: `scripts/rpm/stop.sh`

- [ ] **Step 1: 创建停止脚本**

```bash
#!/bin/bash
set -e

PORT=48921
DATA_DIR="$HOME/.local/share/html-anything"
PID_FILE="$DATA_DIR/html-anything.pid"

# 查找并终止占用端口的进程
PIDS=$(lsof -ti:$PORT 2>/dev/null || true)

if [ -n "$PIDS" ]; then
    echo "正在停止占用端口 $PORT 的进程..."
    kill $PIDS 2>/dev/null || true
    sleep 2
    # 强制终止
    kill -9 $PIDS 2>/dev/null || true
    echo "已停止进程"
else
    echo "端口 $PORT 未被占用"
fi

# 清理 PID 文件
rm -f "$PID_FILE"
```

- [ ] **Step 2: 设置执行权限**

```bash
chmod +x scripts/rpm/stop.sh
```

- [ ] **Step 3: 验证脚本语法**

```bash
bash -n scripts/rpm/stop.sh && echo "Syntax OK"
```
Expected: "Syntax OK"

---

### Task 4: 创建 systemd 用户服务

**Files:**
- Create: `scripts/rpm/html-anything.service`

- [ ] **Step 1: 创建 systemd 服务文件**

```ini
[Unit]
Description=HTML Anything Server
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/html-anything/server
ExecStart=/usr/bin/pnpm start
Environment=PORT=48921
Environment=NODE_ENV=production
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
```

---

### Task 5: 创建桌面快捷方式

**Files:**
- Create: `scripts/rpm/html-anything.desktop`

- [ ] **Step 1: 创建桌面快捷方式文件**

```ini
[Desktop Entry]
Name=html-anything
Comment=HTML Conversion Tool
Exec=/opt/html-anything/bin/start.sh
Icon=html-anything
Terminal=false
Type=Application
Categories=Utility;Development;
StartupNotify=true
```

---

### Task 6: 创建安装后脚本

**Files:**
- Create: `scripts/rpm/install-icons.sh`

- [ ] **Step 1: 创建安装后脚本**

```bash
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

# 重新加载 systemd
systemctl --user daemon-reload

# 启用服务（但不启动，让用户手动启动）
systemctl --user enable html-anything.service 2>/dev/null || true

# 设置正确的文件权限
chown -R "$REAL_USER:" "$HOME_DIR/.local/share/html-anything"
chown -R "$REAL_USER:" "$HOME_DIR/.config/systemd/user/html-anything.service"
chown -R "$REAL_USER:" "$HOME_DIR/.local/share/applications/html-anything.desktop"
chown -R "$REAL_USER:" "$HOME_DIR/Desktop/html-anything.desktop" 2>/dev/null || true

echo "安装完成！"
echo "  - 应用菜单项已创建"
echo "  - 桌面快捷方式已创建"
echo "  - 可通过桌面图标或应用菜单启动"
```

- [ ] **Step 2: 设置执行权限**

```bash
chmod +x scripts/rpm/install-icons.sh
```

---

### Task 7: 创建卸载前脚本

**Files:**
- Create: `scripts/rpm/uninstall-icons.sh`

- [ ] **Step 1: 创建卸载前脚本**

```bash
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
```

- [ ] **Step 2: 设置执行权限**

```bash
chmod +x scripts/rpm/uninstall-icons.sh
```

---

### Task 8: 创建 RPM Spec 文件

**Files:**
- Create: `scripts/rpm/html-anything.spec`

- [ ] **Step 1: 创建 RPM spec 文件**

```spec
Name:           html-anything
Version:        0.1.0
Release:        1%{?dist}
Summary:        HTML Anything - Web conversion tool
License:        Apache-2.0
URL:            https://github.com/html-anything
BuildArch:      noarch

# 依赖
Requires:       systemd
Requires:       nodejs >= 18
Requires:       lsof
Requires:       xdg-utils

%description
HTML Anything is a local web-based HTML conversion tool.
Run as a desktop application with system tray integration.

%prep
# 预构建模式：源码已包含构建产物

%build
# 预构建模式：无需构建

%install
# 创建目录结构
mkdir -p %{buildroot}/opt/html-anything/server
mkdir -p %{buildroot}/opt/html-anything/bin

# 复制构建后的应用
cp -r %{_topdir}/SOURCES/server/* %{buildroot}/opt/html-anything/server/

# 复制脚本
cp %{_topdir}/SOURCES/start.sh %{buildroot}/opt/html-anything/bin/
cp %{_topdir}/SOURCES/stop.sh %{buildroot}/opt/html-anything/bin/

# 复制服务文件和桌面文件
cp %{_topdir}/SOURCES/html-anything.service %{buildroot}/opt/html-anything/
cp %{_topdir}/SOURCES/html-anything.desktop %{buildroot}/opt/html-anything/

# 复制安装脚本
cp %{_topdir}/SOURCES/install-icons.sh %{buildroot}/opt/html-anything/
cp %{_topdir}/SOURCES/uninstall-icons.sh %{buildroot}/opt/html-anything/

%preun
# 卸载前执行
if [ $1 -eq 0 ]; then
    /opt/html-anything/uninstall-icons.sh || true
fi

%post
# 安装后执行
/opt/html-anything/install-icons.sh

%files
/opt/html-anything/

%changelog
* Wed May 21 2026 html-anything Team - 0.1.0
- Initial RPM package
```

---

### Task 9: 创建打包脚本

**Files:**
- Create: `scripts/build-rpm.sh`

- [ ] **Step 1: 创建打包脚本**

```bash
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
NEXT_DIR="$ROOT_DIR/next"
RPM_BUILD_DIR="$ROOT_DIR/rpm-build"
RPM_SOURCES_DIR="$RPM_BUILD_DIR/SOURCES"

echo "=== HTML Anything RPM Builder ==="

# 清理旧构建
rm -rf "$RPM_BUILD_DIR"
mkdir -p "$RPM_SOURCES_DIR"

# Step 1: 构建 Next.js 应用
echo "[1/4] Building Next.js application..."
cd "$NEXT_DIR"
pnpm install --frozen-lockfile
pnpm build

# Step 2: 复制构建产物到 SOURCES
echo "[2/4] Preparing RPM sources..."
cp -r "$NEXT_DIR/.next" "$RPM_SOURCES_DIR/server/"
cp -r "$NEXT_DIR/node_modules" "$RPM_SOURCES_DIR/server/"
cp "$NEXT_DIR/package.json" "$RPM_SOURCES_DIR/server/"
cp -r "$NEXT_DIR/public" "$RPM_SOURCES_DIR/server/public/"

# 复制脚本
cp "$SCRIPT_DIR/rpm/start.sh" "$RPM_SOURCES_DIR/"
cp "$SCRIPT_DIR/rpm/stop.sh" "$RPM_SOURCES_DIR/"
cp "$SCRIPT_DIR/rpm/html-anything.service" "$RPM_SOURCES_DIR/"
cp "$SCRIPT_DIR/rpm/html-anything.desktop" "$RPM_SOURCES_DIR/"
cp "$SCRIPT_DIR/rpm/install-icons.sh" "$RPM_SOURCES_DIR/"
cp "$SCRIPT_DIR/rpm/uninstall-icons.sh" "$RPM_SOURCES_DIR/"

# 复制 spec 文件
cp "$SCRIPT_DIR/rpm/html-anything.spec" "$RPM_BUILD_DIR/SPECS/"

# Step 3: 构建 RPM
echo "[3/4] Building RPM package..."
rpmbuild -ba "$RPM_BUILD_DIR/SPECS/html-anything.spec" \
    --define "_topdir $RPM_BUILD_DIR"

# Step 4: 输出结果
echo "[4/4] Build complete!"
echo ""
echo "RPM packages located at:"
ls -lh "$RPM_BUILD_DIR/RPMS/noarch/"
echo ""
echo "Install with:"
echo "  sudo rpm -ivh $RPM_BUILD_DIR/RPMS/noarch/html-anything-*.rpm"
```

- [ ] **Step 2: 设置执行权限**

```bash
chmod +x scripts/build-rpm.sh
```

---

### Task 10: 添加 next.config.ts 输出配置

**Files:**
- Modify: `next/next.config.ts`

- [ ] **Step 1: 修改 Next.js 配置**

当前内容：
```typescript
const nextConfig: NextConfig = {
};
```

修改为：
```typescript
const nextConfig: NextConfig = {
  output: 'standalone',
};
```

- [ ] **Step 2: 验证配置语法**

```bash
cd next && pnpm typecheck
```
Expected: No errors

---

### Task 11: 验证打包流程

**Files:**
- All created files

- [ ] **Step 1: 运行打包脚本**

```bash
./scripts/build-rpm.sh
```
Expected: RPM builds successfully

- [ ] **Step 2: 验证 RPM 文件生成**

```bash
ls -lh rpm-build/RPMS/noarch/html-anything-*.rpm
```
Expected: RPM file exists

- [ ] **Step 3: 验证 RPM 内容**

```bash
rpm -qlp rpm-build/RPMS/noarch/html-anything-0.1.0-1.el8.noarch.rpm
```
Expected: List of files to be installed

---

### Task 12: 文档更新

**Files:**
- Create: `docs/rpm-packaging.md`

- [ ] **Step 1: 创建打包文档**

```markdown
# RPM Packaging Guide

## Prerequisites

- RPM build tools: `sudo dnf install rpm-build rpmbuild`
- Node.js 18+
- pnpm

## Build

```bash
./scripts/build-rpm.sh
```

## Install

```bash
sudo rpm -ivh rpm-build/RPMS/noarch/html-anything-0.1.0-1.el8.noarch.rpm
```

## Upgrade

```bash
sudo rpm -Uvh rpm-build/RPMS/noarch/html-anything-0.1.0-1.el8.noarch.rpm
```

## Uninstall

```bash
sudo rpm -e html-anything
```

## Usage

After installation:
- Click the "html-anything" icon in Applications menu
- Or click the desktop shortcut "html-anything.desktop"
- The app will auto-start if not running, or open browser if already running
```

---

## Self-Review Checklist

**Spec Coverage:**
- [ ] 桌面图标和应用菜单 → Task 5, Task 6
- [ ] 安装/升级时停止进程 → Task 3, Task 7
- [ ] 启动器智能检测 → Task 2
- [ ] 卸载删除图标 → Task 7
- [ ] 保留用户数据 → Task 7 (注释说明)
- [ ] 冷门端口 48921 → Task 2, Task 3, Task 4

**Placeholder Scan:**
- [ ] 无 TBD/TODO
- [ ] 所有代码步骤包含实际代码
- [ ] 所有命令包含预期输出

**Type Consistency:**
- [ ] 端口号统一使用 48921
- [ ] 路径统一使用 /opt/html-anything
- [ ] 数据目录统一使用 ~/.local/share/html-anything

---

**Plan complete.** Two execution options:

**1. Subagent-Driven (recommended)** - Dispatch fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
