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
