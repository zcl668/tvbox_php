#!/data/data/com.termux/files/usr/bin/bash
# =========================================
# Termux 修复 sources.list + 一键安装 PHP+Nginx
# 网站目录: /storage/emulated/0/zcl/php
# 端口: 8081
# =========================================

set -e

WEB_DIR="/storage/emulated/0/zcl/php"
NGINX_CONF="$HOME/etc/nginx/nginx.conf"
PORT=8081

echo -e "\033[1;34m[INFO] 修复 sources.list...\033[0m"

# 备份旧 sources.list
if [ -f "$PREFIX/etc/apt/sources.list" ]; then
    cp "$PREFIX/etc/apt/sources.list" "$PREFIX/etc/apt/sources.list.bak"
    echo -e "\033[1;33m[INFO] 已备份旧 sources.list\033[0m"
fi

# 写入官方源
cat > "$PREFIX/etc/apt/sources.list" <<EOF
deb https://packages.termux.org/apt/termux-main stable main
EOF

# 更新并升级
echo -e "\033[1;34m[INFO] 更新并升级 Termux...\033[0m"
apt update -y
apt upgrade -y

# 安装依赖
for pkgname in php php-fpm nginx curl wget unzip git termux-api; do
    if ! command -v $pkgname >/dev/null 2>&1; then
        echo -e "\033[1;33m[INFO] 安装 $pkgname...\033[0m"
        pkg install -y $pkgname
    fi
done

# 设置存储权限
termux-setup-storage

# 创建网站目录
mkdir -p "$WEB_DIR"
cd "$WEB_DIR"

# 创建测试 PHP 文件
if [ ! -f "$WEB_DIR/index.php" ]; then
cat > index.php <<'EOF'
<?php
echo "<h1>PHP Server is Running!</h1>";
echo "<p>Server IP: " . $_SERVER['SERVER_ADDR'] . "</p>";
echo "<p>Client IP: " . $_SERVER['REMOTE_ADDR'] . "</p>";
echo "<p>Document Root: " . $_SERVER['DOCUMENT_ROOT'] . "</p>";
?>
EOF
fi

# 获取本机 IP
get_ip() {
    local ip
    ip=$(ip route get 1.2.3.4 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}')
    echo "${ip:-127.0.0.1}"
}
SERVER_IP=$(get_ip)

# 配置 Nginx
mkdir -p $HOME/etc/nginx
cat > $NGINX_CONF <<EOF
worker_processes 1;
events { worker_connections 1024; }
http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;

    server {
        listen $PORT;
        server_name localhost;
        root $WEB_DIR;
        index index.php index.html index.htm;

        location / {
            try_files \$uri \$uri/ /index.php?\$query_string;
        }

        location ~ \.php\$ {
            include fastcgi_params;
            fastcgi_pass 127.0.0.1:9000;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        }
    }
}
EOF

# 创建后台管理脚本
MANAGER="$PREFIX/bin/tvbox-server"
cat > "$MANAGER" <<EOF
#!/data/data/com.termux/files/usr/bin/bash

WEB_DIR="$WEB_DIR"
NGINX_CONF="$NGINX_CONF"
SERVER_IP="$SERVER_IP"
PORT="$PORT"

start_services() {
    pgrep php >/dev/null || nohup php -S 0.0.0.0:\$PORT -t "\$WEB_DIR" >/dev/null 2>&1 &
    pgrep nginx >/dev/null || nohup nginx -c "\$NGINX_CONF" >/dev/null 2>&1 &
    echo "服务已启动: http://\$SERVER_IP:\$PORT"
}

stop_services() {
    pkill php
    pkill nginx
    echo "服务已停止"
}

status_services() {
    local php_status=\$(pgrep php >/dev/null && echo "运行中" || echo "已停止")
    local nginx_status=\$(pgrep nginx >/dev/null && echo "运行中" || echo "已停止")
    echo "PHP 状态: \$php_status"
    echo "Nginx 状态: \$nginx_status"
    echo "访问地址: http://\$SERVER_IP:\$PORT"
}

case "\$1" in
    start) start_services ;;
    stop) stop_services ;;
    status) status_services ;;
    restart)
        stop_services
        start_services
        ;;
    *)
        echo "用法: tvbox-server {start|stop|status|restart}"
        ;;
esac
EOF

chmod +x "$MANAGER"

# Termux 打开自动启动
BASHRC="$HOME/.bashrc"
STARTUP_CMD="pgrep php >/dev/null || nohup php -S 0.0.0.0:$PORT -t $WEB_DIR >/dev/null 2>&1 &; pgrep nginx >/dev/null || nohup nginx -c $NGINX_CONF >/dev/null 2>&1 &"
grep -qxF "$STARTUP_CMD" "$BASHRC" || echo "$STARTUP_CMD" >> "$BASHRC"

# 启动服务
$MANAGER start

echo "========================================"
echo "安装完成！"
echo "网站目录: $WEB_DIR"
echo "访问地址: http://$SERVER_IP:$PORT"
echo "管理命令: tvbox-server {start|stop|status|restart}"
echo "========================================"
