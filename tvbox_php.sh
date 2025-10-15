#!/bin/bash
# ==================================
# tvbox_php 一键安装脚本（Termux + Nginx + PHP 环境管理）
# 端口：8081
# 网站目录：/storage/emulated/0/zcl
# ==================================

WEB_DIR="/storage/emulated/0/zcl"
BASHRC="$PREFIX/etc/bash.bashrc"
PORT=8081

ok() { echo -e "✅ $1"; }
err() { echo -e "❌ $1"; }
skip() { echo -e "⏭️ $1"; }
step() { echo -e "\n🧩 $1"; }

# 智能安装
step "检查并安装必要组件"
pkg update -y >/dev/null 2>&1
pkg upgrade -y >/dev/null 2>&1
REQUIRED_PKGS=("nginx" "php" "php-fpm" "curl" "psmisc")
for pkg in "${REQUIRED_PKGS[@]}"; do
    if dpkg -s "$pkg" &>/dev/null; then
        skip "$pkg 已安装"
    else
        pkg install -y "$pkg" && ok "$pkg 安装完成"
    fi
done

termux-setup-storage

# 配置 Nginx
step "配置 Nginx"
mkdir -p "$PREFIX/logs"
cat > "$PREFIX/etc/nginx/nginx.conf" <<EOF
worker_processes 1;
error_log logs/error.log;
events { worker_connections 1024; }
http {
    include mime.types;
    default_type application/octet-stream;
    sendfile on;
    keepalive_timeout 65;
    server {
        listen $PORT default_server;
        server_name localhost;
        root $WEB_DIR;
        index index.html index.php;
        location / {
            try_files \$uri \$uri/ /index.php?\$args;
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
ok "Nginx 配置完成"

# 配置 PHP-FPM
step "配置 PHP-FPM"
PHP_FPM_CONF="$PREFIX/etc/php-fpm.d/www.conf"
if grep -q "listen = /data" "$PHP_FPM_CONF"; then
    sed -i 's|listen = .*|listen = 127.0.0.1:9000|' "$PHP_FPM_CONF"
fi
ok "PHP-FPM 已配置为 TCP 模式"

# 网站目录和测试页
step "创建网站目录与测试页面"
mkdir -p "$WEB_DIR"
if [ ! -f "$WEB_DIR/index.php" ]; then
    echo "<?php echo '<h1>PHP 服务运行中</h1>'; phpinfo(); ?>" > "$WEB_DIR/index.php"
    ok "测试页已创建：$WEB_DIR/index.php"
else
    skip "测试页已存在"
fi

# 开机自启
step "配置开机自启"
if ! grep -q "tvbox_php.sh" "$BASHRC"; then
    echo -e "\n# 自动启动 tvbox_php 服务" >> "$BASHRC"
    echo "pkill -x nginx >/dev/null 2>&1; pkill -x php-fpm >/dev/null 2>&1" >> "$BASHRC"
    echo "nginx && php-fpm &" >> "$BASHRC"
    echo "echo '✅ tvbox_php 服务自动启动: http://127.0.0.1:$PORT'" >> "$BASHRC"
    ok "开机自启配置完成"
else
    skip "开机自启已存在"
fi

# 启动服务
step "启动 Nginx + PHP-FPM"
pkill -x nginx >/dev/null 2>&1
pkill -x php-fpm >/dev/null 2>&1
nginx && php-fpm
ok "服务已启动: http://127.0.0.1:$PORT"

# 菜单管理
while true; do
    echo -e "\n========= tvbox_php 服务控制菜单 ========="
    echo "1) 启动 Nginx + PHP-FPM"
    echo "2) 停止 Nginx + PHP-FPM"
    echo "3) 查看状态"
    echo "4) 打开浏览器"
    echo "5) 退出菜单"
    echo "6) 关闭 Termux 后台"
    echo "===================================="
    read -p "请输入选项 [1-6]: " choice

    case "$choice" in
        1)
            pkill -x nginx >/dev/null 2>&1
            pkill -x php-fpm >/dev/null 2>&1
            nginx && php-fpm
            ok "服务已启动: http://127.0.0.1:$PORT"
            ;;
        2)
            pkill -x nginx >/dev/null 2>&1
            pkill -x php-fpm >/dev/null 2>&1
            echo "🛑 服务已停止"
            ;;
        3)
            echo -e "\n--- 当前状态 ---"
            pgrep -x nginx &>/dev/null && echo "✅ Nginx 正在运行" || echo "❌ Nginx 未运行"
            pgrep -x php-fpm &>/dev/null && echo "✅ PHP-FPM 正在运行" || echo "❌ PHP-FPM 未运行"
            ;;
        4)
            termux-open "http://127.0.0.1:$PORT"
            ;;
        5)
            echo "退出菜单"
            break
            ;;
        6)
            echo "关闭后台进程 & 退出 Termux"
            pkill -x nginx >/dev/null 2>&1
            pkill -x php-fpm >/dev/null 2>&1
            pkill -f "com.termux" >/dev/null 2>&1
            pkill -f "termux" >/dev/null 2>&1
            exit 0
            ;;
        *)
            echo "无效输入，请输入 1-6"
            ;;
    esac
done