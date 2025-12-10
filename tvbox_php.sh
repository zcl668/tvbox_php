#!/data/data/com.termux/files/usr/bin/bash
set -e
pkg install -y php
termux-setup-storage
PHP_ROOT="/storage/emulated/0/木凡/php"
mkdir -p "$PHP_ROOT"
cat > "$PHP_ROOT/index.php" << 'EOF'
<?php
echo "<h1>PHP Server is Running!</h1>";
echo "<p>Server IP: " . $_SERVER['SERVER_ADDR'] . "</p>";
echo "<p>Client IP: " . $_SERVER['REMOTE_ADDR'] . "</p>";
echo "<p>Document Root: " . $_SERVER['DOCUMENT_ROOT'] . "</p>";
?>
EOF
TARGET_FILE="$PREFIX/etc/bash.bashrc"
STARTUP_CMD="# 自动启动PHP服务
if ! pgrep -f 'php -S 0.0.0.0:9901' > /dev/null; then
    cd '$PHP_ROOT' && nohup php -S 0.0.0.0:9901 > /dev/null 2>&1 &
    echo \"PHP服务启动中...\"
fi"
if ! grep -q "php -S 0.0.0.0:9901" "$TARGET_FILE"; then
    echo -e "\n$STARTUP_CMD" >> "$TARGET_FILE"
    echo "启动配置已添加到 bash.bashrc"
fi
get_ip() {
    local ip
    ip=$(ip route get 1.2.3.4 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}')
    echo "${ip:-0.0.0.0}"
}
SERVER_IP=$(get_ip)
cat > "$PREFIX/bin/tvbox-php" << EOF
#!/data/data/com.termux/files/usr/bin/bash
case "\\$1" in
    start)
        cd "$PHP_ROOT" && nohup php -S 0.0.0.0:9901 > /dev/null 2>&1 &
        echo "PHP服务已启动: http://$SERVER_IP:9901"
        ;;
    stop)
        pkill -f "php -S 0.0.0.0:9901"
        echo "PHP服务已停止"
        ;;
    status)
        if pgrep -f "php -S 0.0.0.0:9901" > /dev/null; then
            echo "PHP服务运行中: http://$SERVER_IP:9901"
        else
            echo "PHP服务未运行"
        fi
        ;;
    restart)
        pkill -f "php -S 0.0.0.0:9901"
        cd "$PHP_ROOT" && nohup php -S 0.0.0.0:9901 > /dev/null 2>&1 &
        echo "PHP服务已重启: http://$SERVER_IP:9901"
        ;;
    *)
        echo "用法: tvbox-php {start|stop|status|restart}"
        echo "根目录: $PHP_ROOT"
        echo "访问地址: http://$SERVER_IP:9901"
        ;;
esac
EOF
chmod +x "$PREFIX/bin/tvbox-php"
cd "$PHP_ROOT" && nohup php -S 0.0.0.0:9901 > /dev/null 2>&1 &
echo "========================================"
echo "配置完成！"
echo "PHP根目录: $PHP_ROOT"
echo "访问地址: http://$SERVER_IP:9901"
echo "管理命令: tvbox-php {start|stop|status|restart}"
echo "========================================"
sleep 1
tvbox-php status
