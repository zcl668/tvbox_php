#!/data/data/com.termux/files/usr/bin/bash
# Termux Nginx + PHP-FPM 美观控制面板
# 网站目录: /storage/emulated/0/zcl/php
# 端口: 8081

PREFIX=$(termux-info | grep "prefix" | awk '{print $2}')
WEB_DIR="/storage/emulated/0/zcl/php"
NGINX_CONF="$PREFIX/etc/nginx/nginx.conf"
PHP_FPM_CONF="$PREFIX/etc/php-fpm.d/www.conf"

# ================== 颜色 & 辅助函数 ==================
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
MAGENTA='\033[1;35m'
RESET='\033[0m'
BOLD='\033[1m'

print_ok() { echo -e "${GREEN}✅ $1${RESET}"; }
print_warn() { echo -e "${YELLOW}⚠️ $1${RESET}"; }
print_err() { echo -e "${RED}❌ $1${RESET}"; }
print_step() { echo -e "${CYAN}--- $1 ---${RESET}"; }
banner() {
echo -e "${MAGENTA}
===========================================
    Termux Nginx + PHP-FPM 控制面板
===========================================
${RESET}"
}

# ================== 检查依赖 ==================
REQUIRED_PKGS=("nginx" "php" "php-fpm" "wget" "curl" "psmisc")
check_package_installed() { command -v "$1" >/dev/null 2>&1; }

print_step "检测并安装必要依赖"
for pkg in "${REQUIRED_PKGS[@]}"; do
    if check_package_installed "$pkg"; then
        print_ok "$pkg 已安装"
    else
        echo "📦 正在安装 $pkg..."
        apt update && apt install -y "$pkg"
        if check_package_installed "$pkg"; then
            print_ok "$pkg 安装完成"
        else
            print_err "$pkg 安装失败，请手动执行：apt install -y $pkg"
        fi
    fi
done

# ================== 网站目录 & 测试文件 ==================
print_step "网站目录与测试文件"
if [ ! -d "$WEB_DIR" ]; then
    mkdir -p "$WEB_DIR"
    print_ok "网站目录已创建：$WEB_DIR"
else
    print_ok "网站目录已存在"
fi

if [ ! -f "$WEB_DIR/index.php" ]; then
    echo "<?php echo '<h1>PHP 服务器运行中</h1>'; phpinfo(); ?>" > "$WEB_DIR/index.php"
    print_ok "测试文件 index.php 已创建"
else
    print_ok "index.php 已存在"
fi

# ================== Nginx 配置 ==================
print_step "配置 Nginx"
mkdir -p "$PREFIX/logs"
if [ ! -f "$NGINX_CONF" ] || ! grep -q "root $WEB_DIR;" "$NGINX_CONF"; then
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

        location / {
            try_files \$uri \$uri/ \$uri.php?\$args;
        }

        location ~ \.php\$ {
            root $WEB_DIR;
            fastcgi_pass 127.0.0.1:9000;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
            include fastcgi_params;
        }
    }
}
EOF
    print_ok "Nginx 配置完成"
else
    print_ok "Nginx 配置已存在"
fi

# ================== PHP-FPM 配置 ==================
print_step "配置 PHP-FPM"
if [ -f "$PHP_FPM_CONF" ]; then
    sed -i 's|listen = .*|listen = 127.0.0.1:9000|' "$PHP_FPM_CONF"
    print_ok "PHP-FPM 配置完成"
else
    print_warn "PHP-FPM 配置文件不存在，跳过"
fi

# ================== 启动服务 ==================
print_step "启动服务"
pkill -x nginx >/dev/null 2>&1
nginx
pkill -x php-fpm >/dev/null 2>&1
php-fpm
sleep 1

NGINX_PID=$(pgrep -x nginx)
PHP_PID=$(pgrep -x php-fpm)

banner
echo -e "${BLUE}==================== 服务状态 ====================${RESET}"
if [ -n "$NGINX_PID" ]; then
    print_ok "Nginx 已启动，PID: $NGINX_PID"
else
    print_err "Nginx 启动失败"
fi

if [ -n "$PHP_PID" ]; then
    print_ok "PHP-FPM 已启动，PID: $PHP_PID"
else
    print_err "PHP-FPM 启动失败"
fi

# 获取局域网 IP
get_ip() {
    IP=$(ip addr show wlan0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1)
    [ -z "$IP" ] && IP="127.0.0.1"
    echo "$IP"
}
LOCAL_IP=$(get_ip)

echo -e "${BLUE}------------------------------------------------${RESET}"
echo -e "${CYAN}🌐 本机访问地址: http://${LOCAL_IP}:8081${RESET}"
echo -e "${BLUE}================================================${RESET}"

# ================== Termux 自动运行 ==================
BASHRC="$HOME/.bashrc"
MARKER="# >>> 自动启动 Nginx/PHP 面板 <<<"
SCRIPT_PATH="$HOME/start_nginx_php.sh"
if ! grep -q "$MARKER" "$BASHRC"; then
cat >> "$BASHRC" <<EOF

$MARKER
# 打开 Termux 自动启动 Nginx + PHP-FPM 面板
$SCRIPT_PATH
# <<< 自动启动 Nginx/PHP 面板 <<<
EOF
    print_ok "Termux 打开时将自动运行脚本"
else
    print_ok "自动运行逻辑已存在"
fi

print_ok "部署完成！访问 http://$LOCAL_IP:8081/index.php 测试"
