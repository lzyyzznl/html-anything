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
sudo rpm -ivh rpm-build/RPMS/x86_64/html-anything-0.1.0-1.el8.x86_64.rpm
```

## Upgrade

```bash
sudo rpm -Uvh rpm-build/RPMS/x86_64/html-anything-0.1.0-1.el8.x86_64.rpm
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
