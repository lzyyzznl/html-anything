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
