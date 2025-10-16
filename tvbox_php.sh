#!/data/data/com.termux/files/usr/bin/bash

# ================================== 函数定义 ==================================
print_ok() { echo -e "\033[1;32m[OK]\033[0m $1"; }
print_skip() { echo -e "\033[1;33m[SKIP]\033[0m $1"; }
print_err() { echo -e "\033[1;31m[ERR]\033[0m $1"; }
print_step() { echo -e "\n\033[1;34m==> $1\033[0m"; }

stop_services() {
    pkill -x nginx >/dev/null 2>&1
    pkill -x php-fpm >/dev/null 2>&1
    print_ok "后台 Nginx 和 PHP-FPM 已停止"
}

# ================================== 安装依赖 ==================================
REQUIRED_PKGS=("nginx" "php" "php-fpm" "unzip" "wget" "python" "curl" "psmisc")
for pkg in "${REQUIRED_PKGS[@]}"; do
    if dpkg -l | grep -qw "$pkg"; then
        print_skip "$pkg 已安装"
    else
        echo "📦 安装 $pkg..."
        apt update && apt install -y "$pkg"
        if dpkg -l | grep -qw "$pkg"; then
            print_ok "$pkg 安装完成"
        else
            print_err "$pkg 安装失败，请手动执行：apt install -y $pkg"
        fi
    fi
done

# ================================== 网站目录和测试文件 ==================================
WEB_DIR="/storage/emulated/0/zcl/php"
mkdir -p "$WEB_DIR"
print_ok "网站目录已创建：$WEB_DIR"

if [ ! -f "$WEB_DIR/index.php" ]; then
    echo "<?php echo '<h1>PHP 服务器运行中</h1>'; phpinfo(); ?>" > "$WEB_DIR/index.php"
    print_ok "index.php 测试文件已创建"
else
    print_skip "index.php 已存在"
fi

# ================================== Nginx 配置 ==================================
NGINX_CONF="$PREFIX/etc/nginx/nginx.conf"
mkdir -p "$(dirname "$NGINX_CONF")"
cat > "$NGINX_CONF" <<EOF
worker_processes 1;
error_log logs/error.log;
events { worker_connections 1024; }
http {
    include mime.types;
    default_type application/octet-stream;
    charset utf-8;
    sendfile on;
    keepalive_timeout 65;
    server {
        listen 8081 default_server;
        server_name localhost;
        root $WEB_DIR;
        index index.html index.htm index.php;
        location / { try_files \$uri \$uri/ \$uri.php?\$args; }
        location ~ \.php\$ {
            root $WEB_DIR;
            fastcgi_pass 127.0.0.1:9000;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
            include fastcgi_params;
        }
        error_page 500 502 503 504 /50x.html;
        location = /50x.html { root $WEB_DIR; }
    }
}
EOF
print_ok "Nginx 配置完成"

# ================================== PHP-FPM 配置 ==================================
PHP_FPM_CONF="$PREFIX/etc/php-fpm.d/www.conf"
if [ -f "$PHP_FPM_CONF" ]; then
    sed -i 's|listen = /data/data/com.termux/files/usr/var/run/php-fpm.sock|listen = 127.0.0.1:9000|' "$PHP_FPM_CONF"
    print_ok "PHP-FPM 配置已更新为 TCP 模式"
fi

# ================================== 启动 Nginx + PHP-FPM ==================================
stop_services
nginx
php-fpm
sleep 1
pgrep -x nginx >/dev/null && print_ok "Nginx 已启动" || print_err "Nginx 启动失败"
pgrep -x php-fpm >/dev/null && print_ok "PHP-FPM 已启动" || print_err "PHP-FPM 启动失败"

# ================================== Termux 自启 ==================================
BASHRC="$HOME/.bashrc"
MARKER="# >>> 自动启动 Nginx 和 PHP-FPM <<<"
sed -i "/# >>> 自动启动 Nginx 和 PHP-FPM/,/# <<< 自动启动 Nginx 和 PHP-FPM/d" "$BASHRC"
cat >> "$BASHRC" <<'EOF'

# >>> 自动启动 Nginx 和 PHP-FPM <<<
pkill -x nginx >/dev/null 2>&1
pkill -x php-fpm >/dev/null 2>&1
nginx >/dev/null 2>&1
php-fpm >/dev/null 2>&1
# <<< 自动启动 Nginx 和 PHP-FPM <<<
EOF
print_ok "已添加 Termux 自启逻辑"

# ================================== 提示操作 ==================================
echo -e "\n✅ 部署完成，访问网站： http://127.0.0.1:8081"
echo -e "🛑 若需关闭后台服务，请执行： stop_services"
