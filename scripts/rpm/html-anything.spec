Name:           html-anything
Version:        0.1.0
Release:        1%{?dist}
Summary:        HTML Anything - Web conversion tool
License:        Apache-2.0
URL:            https://github.com/html-anything
# 自动检测架构（包含 node_modules 二进制文件）

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
# 获取第一个非 root 的普通用户（UID >= 1000）
TARGET_USER=$(awk -F: '$3 >= 1000 && $3 < 65534 {print $1; exit}' /etc/passwd)
if [ -n "$TARGET_USER" ]; then
    export TARGET_USER
    export HOME_DIR=$(getent passwd "$TARGET_USER" | cut -d: -f6)
    export REAL_USER="$TARGET_USER"
    /opt/html-anything/install-icons.sh
else
    echo "警告：未找到普通用户，跳过桌面集成"
fi

%files
/opt/html-anything/

%changelog
* Wed May 21 2026 html-anything Team - 0.1.0
- Initial RPM package
