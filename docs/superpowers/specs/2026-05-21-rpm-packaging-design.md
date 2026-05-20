# RPM Packaging Design Specification

**日期**: 2026-05-21  
**项目**: html-anything  
**版本**: 0.1.0

---

## 1. 概述

将 html-anything Next.js 应用打包为 RPM 包，支持在个人桌面环境（Fedora/CentOS/RHEL）上以单用户模式安装和运行。

### 1.1 核心需求

- 桌面快捷方式 + 应用菜单启动器
- 安装/升级时自动停止占用端口的进程
- 启动器检测应用运行状态，智能启动
- 卸载时删除安装文件，保留用户数据
- 使用冷门端口 48921 避免冲突

---

## 2. 架构设计

### 2.1 安装路径规划

| 路径 | 用途 | 卸载策略 |
|------|------|----------|
| `/opt/html-anything/` | 应用主目录 | 删除 |
| `/opt/html-anything/bin/` | 启动/停止脚本 | 删除 |
| `/opt/html-anything/server/` | 构建后的 Next.js 应用 | 删除 |
| `~/.local/share/applications/html-anything.desktop` | 应用菜单项 | 删除 |
| `~/Desktop/html-anything.desktop` | 桌面快捷方式 | 删除 |
| `~/.local/share/html-anything/` | 用户数据/配置 | **保留** |
| `~/.config/systemd/user/html-anything.service` | systemd 服务 | 删除 |

### 2.2 端口策略

- **默认端口**: 48921
- **检测方式**: `lsof -ti:48921` 或 `ss -tlnp | grep 48921`
- **进程管理**: 通过 systemd 用户服务 + 脚本双重管理

---

## 3. 核心组件

### 3.1 RPM Spec 文件 (`html-anything.spec`)

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

# 安装路径
%define _prefix /opt
%define app_name html-anything

%description
HTML Anything is a local web-based HTML conversion tool.

%prep
# 源码准备（实际使用预构建包）

%build
# 预构建模式：此阶段为空

%install
# 安装文件到构建根目录
mkdir -p %{buildroot}/opt/html-anything
cp -r server/* %{buildroot}/opt/html-anything/server/
mkdir -p %{buildroot}/opt/html-anything/bin
cp scripts/rpm/start.sh %{buildroot}/opt/html-anything/bin/
cp scripts/rpm/stop.sh %{buildroot}/opt/html-anything/bin/

%preun
# 卸载前停止服务
if [ $1 -eq 0 ]; then
    systemctl --user stop html-anything.service 2>/dev/null || true
    systemctl --user disable html-anything.service 2>/dev/null || true
fi

%post
# 安装后创建服务和快捷方式
systemctl --user daemon-reload
systemctl --user enable html-anything.service 2>/dev/null || true

%files
# 文件列表
/opt/html-anything/

%changelog
```

### 3.2 启动脚本 (`/opt/html-anything/bin/start.sh`)

```bash
#!/bin/bash
set -e

PORT=48921
APP_DIR="/opt/html-anything/server"
PID_FILE="$HOME/.local/share/html-anything/html-anything.pid"

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
nohup pnpm start > "$HOME/.local/share/html-anything/html-anything.log" 2>&1 &
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

echo "警告：应用启动超时"
exit 1
```

### 3.3 停止脚本 (`/opt/html-anything/bin/stop.sh`)

```bash
#!/bin/bash
set -e

PORT=48921

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
rm -f "$HOME/.local/share/html-anything/html-anything.pid"
```

### 3.4 systemd 用户服务 (`html-anything.service`)

```ini
[Unit]
Description=HTML Anything Server
After=network.target

[Service]
Type=simple
User=%i
WorkingDirectory=/opt/html-anything/server
ExecStart=/usr/bin/pnpm start
Environment=PORT=48921
Environment=NODE_ENV=production
Restart=on-failure
RestartSec=5
PIDFile=/home/%i/.local/share/html-anything/html-anything.pid

[Install]
WantedBy=default.target
```

### 3.5 桌面快捷方式 (`html-anything.desktop`)

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

## 4. 打包流程

### 4.1 构建步骤

1. **构建 Next.js 应用**
   ```bash
   cd next/
   pnpm install --frozen-lockfile
   pnpm build
   ```

2. **准备打包目录**
   ```bash
   mkdir -p rpm-build/SOURCES
   cp -r next/.next rpm-build/SOURCES/server/
   cp -r next/node_modules rpm-build/SOURCES/server/
   cp next/package.json rpm-build/SOURCES/server/
   ```

3. **创建 RPM 包**
   ```bash
   rpmbuild -ba html-anything.spec --define "_topdir $(pwd)/rpm-build"
   ```

### 4.2 安装测试

```bash
# 安装 RPM
sudo rpm -ivh html-anything-0.1.0-1.el8.noarch.rpm

# 或升级
sudo rpm -Uvh html-anything-0.1.0-1.el8.noarch.rpm

# 验证
systemctl --user status html-anything.service
```

---

## 5. 错误处理

| 场景 | 处理方式 |
|------|----------|
| 端口被占用 | 启动脚本检测后直接打开浏览器 |
| 应用启动失败 | 日志记录到 `~/.local/share/html-anything/html-anything.log` |
| systemd 服务不可用 | 降级为纯脚本启动 |
| 卸载时服务未运行 | `%preun` 脚本使用 `|| true` 忽略错误 |

---

## 6. 文件清单

```
html-anything-0.1.0/
├── html-anything.spec          # RPM spec 文件
├── scripts/rpm/
│   ├── start.sh                # 启动脚本
│   ├── stop.sh                 # 停止脚本
│   └── html-anything.service   # systemd 服务模板
├── next/                       # Next.js 源码（构建用）
└── docs/
    └── superpowers/specs/
        └── 2026-05-21-rpm-packaging-design.md
```

---

## 7. 验收标准

- [ ] RPM 包可成功安装到 CentOS/RHEL/Fedora 系统
- [ ] 安装后自动创建桌面快捷方式和应用菜单项
- [ ] 点击图标可正确启动应用或打开已运行的应用
- [ ] 升级时自动停止旧版本进程
- [ ] 卸载后删除所有安装文件，保留用户数据
- [ ] 卸载后可重新安装

---

## 8. 后续考虑

- 图标资源：需要设计或提供 `html-anything.svg` 图标
- 多用户支持：未来可扩展为系统级服务
- 自动更新：可集成 dnf 自动更新机制
