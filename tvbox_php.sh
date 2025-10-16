#!/data/data/com.termux/files/usr/bin/bash
set -e

# ================================== 彩色打印函数 ==================================
print_ok()    { echo -e "\033[1;32m[✔] $1\033[0m"; }
print_err()   { echo -e "\033[1;31m[✖] $1\033[0m"; }
print_warn()  { echo -e "\033[1;33m[⚠] $1\033[0m"; }
print_step()  { echo -e "\n\033[1;34m===== $1 =====\033[0m"; }
print_skip()  { echo -e "\033[1;36m[→] $1\033[0m"; }

check_package_installed() {
    dpkg -s "$1" >/dev/null 2>&1
}

# ================================== 安装必要依赖 ==================================
REQUIRED_PKGS=("nginx" "php" "php-fpm")
for pkg in "${REQUIRED_PKGS[@]}"; do
    if check_package_installed "$pkg"; then
        print_skip "$pkg 已安装"
    else
        echo "📦 安装 $pkg..."
        apt update -y
        apt install -y "$pkg"
        if check_package_installed "$pkg"; then
            print_ok "$pkg 安装完成"
        else
            print_err "$pkg 安装失败，请手动安装"
        fi
    fi
done

# ================================== Nginx 配置 ==================================
PREFIX="$PREFIX"
NGINX_CONF="$PREFIX/etc/nginx/nginx.conf"

print_step "Nginx 配置"

# mime.types
if [ ! -f "$PREFIX/etc/nginx/mime.types" ] || [ ! -s "$PREFIX/etc/nginx/mime.types" ]; then
    cat > "$PREFIX/etc/nginx/mime.types" <<'EOF'
types {
    text/html html htm shtml;
    text/css css;
    text/xml xml;
    image/gif gif;
    image/jpeg jpeg jpg;
    application/javascript js;
    application/json json;
    image/png png;
    audio/mpeg mp3;
    video/mp4 mp4;
}
EOF
    print_ok "mime.types 配置完成"
else
    print_skip "mime.types 已存在"
fi

# nginx.conf
if [ ! -f "$NGINX_CONF" ] || ! grep -q "root /storage/emulated/0/zcl/php;" "$NGINX_CONF"; then
cat > "$NGINX_CONF" <<'EOF'
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
        charset utf-8;
        root /storage/emulated/0/zcl/php;
        index index.html index.htm index.php;
        location / {
            try_files $uri $uri/ $uri.php?$args;
        }
        error_page 500 502 503 504 /50x.html;
        location = /50x.html { root /storage/emulated/0/zcl/php; }
        location ~ \.php$ {
            root /storage/emulated/0/zcl/php;
            fastcgi_pass 127.0.0.1:9000;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            include fastcgi_params;
        }
    }
}
EOF
    print_ok "Nginx 主配置完成"
else
    print_skip "Nginx 主配置已存在"
fi

# ================================== PHP-FPM 配置 ==================================
PHP_FPM_CONF="$PREFIX/etc/php-fpm.d/www.conf"
print_step "PHP-FPM 配置"

if [ -f "$PHP_FPM_CONF" ]; then
    sed -i 's|listen = /data/data/com.termux/files/usr/var/run/php-fpm.sock|listen = 127.0.0.1:9000|' "$PHP_FPM_CONF"
    print_ok "PHP-FPM 配置已改为 TCP 模式"
else
    print_warn "PHP-FPM 配置文件不存在，跳过"
fi

# ================================== 网站目录与测试文件 ==================================
WEB_DIR="/storage/emulated/0/zcl/php"
print_step "网站目录配置"

mkdir -p "$WEB_DIR"
print_ok "网站目录已创建：$WEB_DIR"

if [ ! -f "$WEB_DIR/index.php" ]; then
    echo "<?php echo '<h1>PHP 服务器运行中</h1>'; phpinfo(); ?>" > "$WEB_DIR/index.php"
    print_ok "index.php 测试文件已创建"
else
    print_skip "index.php 已存在"
fi

# ================================== 启动 Nginx 和 PHP-FPM ==================================
start_services() {
    pkill -x nginx >/dev/null 2>&1
    pkill -x php-fpm >/dev/null 2>&1
    nginx
    php-fpm
    sleep 1
    print_ok "Nginx & PHP-FPM 已启动"
}
stop_services() {
    pkill -x nginx >/dev/null 2>&1
    pkill -x php-fpm >/dev/null 2>&1
    print_warn "Nginx & PHP-FPM 已停止"
}

start_services

# ================================== Termux 自启配置 ==================================
BASHRC="$HOME/.bashrc"
MARKER="# >>> Termux 自动启动 Nginx & PHP-FPM <<<"
sed -i "/# >>> Termux 自动启动 Nginx & PHP-FPM/,/# <<< Termux 自动启动 Nginx & PHP-FPM/d" "$BASHRC"

cat >> "$BASHRC" <<'EOF'

# >>> Termux 自动启动 Nginx & PHP-FPM <<<
WEB_DIR="/storage/emulated/0/zcl/php"

start_nginx() {
    pkill -x nginx >/dev/null 2>&1
    nginx
    sleep 1
}

start_phpfpm() {
    pkill -x php-fpm >/dev/null 2>&1
    php-fpm
    sleep 1
}

stop_nginx() {
    pkill -x nginx >/dev/null 2>&1
}

stop_phpfpm() {
    pkill -x php-fpm >/dev/null 2>&1
}

start_nginx
start_phpfpm

echo -e "\033[1;32m✅ Nginx & PHP-FPM 已自启\033[0m"
echo -e "🔹 网站目录: $WEB_DIR"
echo -e "🔹 本地访问: http://127.0.0.1:8081"
echo -e "\033[1;33m提示：输入 stop_nginx 或 stop_phpfpm 可停止对应服务\033[0m"
# <<< Termux 自动启动 Nginx & PHP-FPM <<<

EOF

print_ok "Termux 自启逻辑已配置完成"

echo -e "\n\033[1;32m🎉 部署完成，访问 http://127.0.0.1:8081 查看效果\033[0m"
