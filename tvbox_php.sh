#!/data/data/com.termux/files/usr/bin/bash
# =========================================
# Termux PHP 自动配置脚本（可后台启动/停止/状态/重启）
# 网站目录: /storage/emulated/0/zcl/php
# =========================================

set -e  # 遇到错误立即退出

# ===== 检查必要命令 =====
for cmd in php termux-setup-storage; do
    command -v $cmd >/dev/null 2>&1 || { echo "$cmd 未安装，请先安装"; exit 1; }
done

# ===== 安装 PHP =====
pkg install -y php

# ===== 设置存储权限 =====
termux-setup-storage

# ===== 创建 PHP 根目录 =====
PHP_ROOT="/storage/emulated/0/zcl/php"
mkdir -p "$PHP_ROOT"

# ===== 创建测试 index.php =====
cat > "$PHP_ROOT/index.php" <<'EOF'
<?php
echo "<h1>PHP Server is Running!</h1>";
echo "<p>Server IP: " . $_SERVER['SERVER_ADDR'] . "</p>";
echo "<p>Client IP: " . $_SERVER['REMOTE_ADDR'] . "</p>";
echo "<p>Document Root: " . $_SERVER['DOCUMENT_ROOT'] . "</p>";
?>
EOF

# ===== 获取本机 IP 地址 =====
get_ip() {
    local ip
    ip=$(ip route get 1.2.3.4 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}')
    echo "${ip:-127.0.0.1}"
}
SERVER_IP=$(get_ip)

# ===== 配置 Termux 打开自动启动 =====
TARGET_FILE="$PREFIX/etc/bash.bashrc"
STARTUP_CMD="# 自动启动 PHP 服务
if ! pgrep -f 'php -S 0.0.0.0:8081' >/dev/null; then
    cd '$PHP_ROOT' && nohup php -S 0.0.0.0:8081 >/dev/null 2>&1 &
    echo 'PHP服务启动中...'
fi"

if ! grep -q "php -S 0.0.0.0:8081" "$TARGET_FILE"; then
    echo -e "\n$STARTUP_CMD" >> "$TARGET_FILE"
    echo "启动配置已添加到 bash.bashrc"
fi

# ===== 创建独立管理脚本 =====
MANAGER="$PREFIX/bin/tvbox-php"
cat > "$MANAGER" <<EOF
#!/data/data/com.termux/files/usr/bin/bash

PHP_ROOT="$PHP_ROOT"
SERVER_IP="$SERVER_IP"

start_service() {
    if ! pgrep -f "php -S 0.0.0.0:8081" >/dev/null; then
        cd "\$PHP_ROOT" && nohup php -S 0.0.0.0:8081 >/dev/null 2>&1 &
        echo "PHP服务已启动: http://\$SERVER_IP:8081"
    else
        echo "PHP服务已在运行: http://\$SERVER_IP:8081"
    fi
}

stop_service() {
    pkill -f "php -S 0.0.0.0:8081" && echo "PHP服务已停止"
}

status_service() {
    if pgrep -f "php -S 0.0.0.0:8081" >/dev/null; then
        echo "PHP服务运行中: http://\$SERVER_IP:8081"
    else
        echo "PHP服务未运行"
    fi
}

case "\$1" in
    start) start_service ;;
    stop) stop_service ;;
    status) status_service ;;
    restart)
        stop_service
        start_service
        ;;
    *)
        echo "用法: tvbox-php {start|stop|status|restart}"
        echo "PHP根目录: \$PHP_ROOT"
        echo "访问地址: http://\$SERVER_IP:8081"
        ;;
esac
EOF

chmod +x "$MANAGER"

# ===== 启动服务 =====
cd "$PHP_ROOT"
nohup php -S 0.0.0.0:8081 >/dev/null 2>&1 &

# ===== 输出信息 =====
echo "========================================"
echo "配置完成！"
echo "PHP根目录: $PHP_ROOT"
echo "访问地址: http://$SERVER_IP:8081"
echo "管理命令: tvbox-php {start|stop|status|restart}"
echo "========================================"

# ===== 等待一秒并显示状态 =====
sleep 1
tvbox-php status
