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

# 使用 pnpm deploy 生成自包含的生产部署目录（仅生产依赖，无 symlink）
pnpm --filter @html-anything/next deploy --prod --legacy "$RPM_SOURCES_DIR/server"

# 叠加构建产物（.next 在 .gitignore 中，deploy 不会包含）
cp -r "$NEXT_DIR/.next" "$RPM_SOURCES_DIR/server/"

# 复制脚本
cp "$SCRIPT_DIR/rpm/start.sh" "$RPM_SOURCES_DIR/"
cp "$SCRIPT_DIR/rpm/stop.sh" "$RPM_SOURCES_DIR/"
cp "$SCRIPT_DIR/rpm/html-anything.service" "$RPM_SOURCES_DIR/"
cp "$SCRIPT_DIR/rpm/html-anything.desktop" "$RPM_SOURCES_DIR/"
cp "$SCRIPT_DIR/rpm/install-icons.sh" "$RPM_SOURCES_DIR/"
cp "$SCRIPT_DIR/rpm/uninstall-icons.sh" "$RPM_SOURCES_DIR/"

# 复制 spec 文件
mkdir -p "$RPM_BUILD_DIR/SPECS"
cp "$SCRIPT_DIR/rpm/html-anything.spec" "$RPM_BUILD_DIR/SPECS/"

# Step 3: 构建 RPM
echo "[3/4] Building RPM package..."
rpmbuild -ba "$RPM_BUILD_DIR/SPECS/html-anything.spec" \
    --define "_topdir $RPM_BUILD_DIR"

# Step 4: 输出结果
echo "[4/4] Build complete!"
echo ""
echo "RPM packages located at:"
ls -lh "$RPM_BUILD_DIR/RPMS/x86_64/"
echo ""
echo "Install with:"
echo "  sudo rpm -ivh $RPM_BUILD_DIR/RPMS/x86_64/html-anything-*.rpm"
