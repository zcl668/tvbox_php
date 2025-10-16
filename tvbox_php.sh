#!/bin/bash
# Termux服务自启脚本（终极修复版 v3.0：进程杀尽 + 端口释放 + 原子更新 + 顶级视觉提示）

termux-wake-lock




# ================================== 基础工具函数 ==================================
color() { echo -e "\033[1;$1m$2\033[0m"; }
print_step() { echo -e "\n$(color 34 "===== $1 =====")"; }
print_ok() { echo "  $(color 32 "✅ $1")"; }
print_warn() { echo "  $(color 33 "⚠️ $1")"; }
print_skip() { echo "  $(color 36 "⏭️ $1")"; }
print_err() { echo "  $(color 31 "❌ $1")"; return 1; }

# 服务状态检查
check_service() {
    local name=$1
    local process=$2
    if pgrep -x "$process" >/dev/null 2>&1; then
        local pids=$(pgrep -x "$process" | tr '\n' ' ')
        echo "  $(color 32 "✅ $name 运行中") (PID: $pids)"
        return 0
    else
        echo "  $(color 31 "❌ $name 未运行") (手动启动：$process)"
        return 1
    fi
}

# 智能判断软件是否已安装
check_package_installed() {
    local pkg=$1
    if dpkg -l | grep -q "^ii  $pkg "; then
        return 0  # 已安装
    else
        return 1  # 未安装
    fi
}


# ================================== 核心1：智能IP获取 ==================================
get_smart_ip() {
    local IP=""
    IP=$(getprop dhcp.wlan0.ipaddress 2>/dev/null)
    IP=$(echo "$IP" | tr '_' '.' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' 2>/dev/null)
    if [ -n "$IP" ]; then
        echo "$IP"
        return 0
    fi

    IP=$(getprop dhcp.eth0.ipaddress 2>/dev/null)
    IP=$(echo "$IP" | tr '_' '.' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' 2>/dev/null)
    if [ -n "$IP" ]; then
        echo "$IP"
        return 0
    fi

    if command -v python >/dev/null 2>&1; then
        IP=$(python -c "import socket; s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM); s.connect(('8.8.8.8',80)); print(s.getsockname()[0]); s.close()" 2>/dev/null)
        if [ -n "$IP" ] && echo "$IP" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' >/dev/null; then
            echo "$IP"
            return 0
        fi
    fi

    echo "127.0.0.1"
    return 0
}




# ================================== 核心3：启动面板展示 ==================================
show_startup_dashboard() {
    clear
    WEB_DIR="/storage/emulated/0/zcl"
    echo -e "$(color 35 "==============================================")"
    echo -e "  📱 Termux 服务状态面板"
    echo -e "$(color 35 "==============================================")"

    local URL_DATA=$(get_latest_json_urls "$WEB_DIR")
    local IP=$(echo "$URL_DATA" | awk '{print $1}')
    local AA_JSON_URL=$(echo "$URL_DATA" | awk '{print $2}')
    local AAA_JSON_URL=$(echo "$URL_DATA" | awk '{print $3}')
    local AA_EXIST=$(echo "$URL_DATA" | awk '{print $4}')
    local AAA_EXIST=$(echo "$URL_DATA" | awk '{print $5}')

    echo -e "\n$(color 36 "📊 服务运行状态:")"
    check_service "Nginx" "nginx"
    check_service "PHP-FPM" "php-fpm"
    
    

    echo -e "\n$(color 36 "🌐 局域网访问地址:")"
    if [[ "$IP" != "127.0.0.1" ]]; then
        if [[ "$IP" =~ ^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[0-1])) ]]; then
            echo "  🔹 当前局域网IP: $(color 32 "$IP")"
            echo -e "  📌 aa.json 访问: $(color 32 "$AA_JSON_URL")"
            echo -e "  📌 aaa.json 访问: $(color 32 "$AAA_JSON_URL")"
        else
            echo "  🔹 当前IP: $(color 32 "$IP")"
            echo -e "  📌 aa.json 访问: $(color 32 "$AA_JSON_URL")"
            echo -e "  📌 aaa.json 访问: $(color 32 "$AAA_JSON_URL")"
        fi
    else
        echo "  🔹 当前IP: $(color 33 "$IP")（需同一设备访问）"
        echo -e "  📌 aa.json 访问: $(color 32 "$AA_JSON_URL")"
        echo -e "  📌 aaa.json 访问: $(color 32 "$AAA_JSON_URL")"
    fi

    echo -e "\n$(color 36 "📄 核心文件状态:")"
    
    echo "  🔹 网站目录: $(color 36 "$WEB_DIR")"

    echo -e "\n$(color 36 "💡 快速操作指南:")"
    echo "  - 重启服务: $(color 33 "pkill nginx; pkill php-fpm; nginx; php-fpm")"
    echo "  - 强制更新文件: $(color 33 "rm -rf /storage/emulated/0/lz && bash ~/.bashrc")"
    echo "  - 测试aa.json: $(color 33 "curl $AA_JSON_URL")"
    echo -e "\n$(color 35 "==============================================")"
}

# ================================== 核心4：二次启动判断 ==================================
is_second_start() {
    BASHRC="$HOME/.bashrc"
    if grep -q "# >>> 自动启动 Nginx 和 PHP-FPM（无tput版）<<<" "$BASHRC" || grep -q "# >>> 自动启动 yt001（带自动更新）<<<" "$BASHRC"; then
        return 0
    else
        return 1
    fi
}

# ================================== 存储权限检查 ==================================
if [ ! -d "$HOME/storage" ]; then
    echo "正在请求存储权限..."
    termux-setup-storage
    sleep 5
    if [ ! -d "$HOME/storage" ]; then
        echo "❌ 未获得存储权限，请手动运行 termux-setup-storage"
        exit 1
    fi
    print_ok "存储权限已获取"
else
    print_skip "存储权限已存在，跳过请求"


    else
        print_warn "源文件不存在，无法更新和启动"
    fi
    
    echo -e "\n$(color 36 "🔄 加载服务状态面板...")"
    show_startup_dashboard
    
    echo -e "\n$(color 32 "✅ 所有启动流程已完成")"
    exit 0
fi

# ================================== 首次启动：智能安装 ==================================
print_step "智能安装检测（仅安装未装组件）"

if [ ! -f "$HOME/.termux_first_update_done" ]; then
    echo -e "\n正在执行系统更新（首次启动）..."
    apt update -y && apt upgrade -y && apt autoremove -y && apt autoclean
    touch "$HOME/.termux_first_update_done"
    print_ok "系统更新完成"
else
    echo -e "\n$(print_skip "系统已更新过，跳过")"
fi

REQUIRED_PKGS=("nginx" "php" "php-fpm" "unzip" "wget" "python" "curl" "psmisc")
for pkg in "${REQUIRED_PKGS[@]}"; do
    if check_package_installed "$pkg"; then
        print_skip "$pkg 已安装，跳过"
    else
        echo "📦 正在安装 $pkg..."
        apt install -y "$pkg"
        if check_package_installed "$pkg"; then
            print_ok "$pkg 安装完成"
        else
            print_err "$pkg 安装失败，请手动执行：apt install -y $pkg"
        fi
    fi
done

# ================================== Nginx配置 ==================================
print_step "Nginx 配置检测"

if [ ! -d "$PREFIX/logs" ]; then
    mkdir -p "$PREFIX/logs"
    print_ok "Nginx 日志目录创建完成"
else
    print_skip "Nginx 日志目录已存在，跳过"
fi

if [ ! -f "$PREFIX/etc/nginx/mime.types" ] || [ ! -s "$PREFIX/etc/nginx/mime.types" ]; then
    cat > "$PREFIX/etc/nginx/mime.types" <<'EOF'
types {
    text/html                             html htm shtml;
    text/css                              css;
    text/xml                              xml;
    image/gif                             gif;
    image/jpeg                            jpeg jpg;
    application/javascript                js;
    application/atom+xml                  atom;
    application/rss+xml                   rss;
    application/json                      json;
    image/png                             png;
    image/svg+xml                         svg svgz;
    image/vnd.microsoft.icon              ico;
    application/x-font-ttf                ttf;
    application/x-font-woff               woff;
    font/opentype                         otf;
    application/vnd.ms-fontobject         eot;
    application/octet-stream              bin exe dll;
    application/octet-stream              deb rpm;
    application/octet-stream              iso img;
    audio/midi                            mid midi kar;
    audio/mpeg                            mp3;
    video/mp4                             mp4;
    video/mpeg                            mpeg mpg;
}
EOF
    print_ok "Nginx mime.types 配置完成"
else
    print_skip "Nginx mime.types 已存在且有效，跳过"
fi

NGINX_CONF="$PREFIX/etc/nginx/nginx.conf"
if [ ! -f "$NGINX_CONF" ] || ! grep -q "root /storage/emulated/0/lz;" "$NGINX_CONF"; then
    cat > "$NGINX_CONF" <<'EOF'
# Nginx for Termux
worker_processes 1;
error_log logs/error.log;
events {
    worker_connections 1024;
}
http {
    include mime.types;
    default_type application/octet-stream;
    charset utf-8;
    sendfile on;
    keepalive_timeout 65;
    server {
        listen 8080 default_server;
        server_name localhost;
        charset utf-8;
        root /storage/emulated/0/zcl;
        index index.html index.htm index.php;
        location / {
            try_files $uri $uri/ $uri.php?$args;
        }
        error_page 500 502 503 504 /50x.html;
        location = /50x.html {
            root /storage/emulated/0/zcl;
        }
        location ~ \.php$ {
            root /storage/emulated/0/zcl;
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
    print_skip "Nginx 主配置已存在且有效，跳过"
fi

# ================================== PHP-FPM配置 ==================================
print_step "PHP-FPM 配置检测"

PHP_FPM_CONF="$PREFIX/etc/php-fpm.d/www.conf"
if [ ! -f "$PHP_FPM_CONF" ] || ! grep -q "listen = 127.0.0.1:9000" "$PHP_FPM_CONF"; then
    sed -i 's|listen = /data/data/com.termux/files/usr/var/run/php-fpm.sock|listen = 127.0.0.1:9000|' "$PHP_FPM_CONF"
    print_ok "PHP-FPM 配置已更新为TCP模式"
else
    print_skip "PHP-FPM 配置已为TCP模式，跳过"
fi

# ================================== 网站目录创建 ==================================
print_step "网站目录配置"
WEB_DIR="/storage/emulated/0/lz"
if [ ! -d "$WEB_DIR" ]; then
    mkdir -p "$WEB_DIR"
    print_ok "网站目录创建完成：$WEB_DIR"
else
    print_skip "网站目录已存在：$WEB_DIR"
fi

# ================================== 测试文件创建 ==================================
if [ ! -f "$WEB_DIR/index.php" ]; then
    echo "<?php echo '<h1>PHP 服务器运行中</h1>'; phpinfo(); ?>" > "$WEB_DIR/index.php"
    print_ok "index.php 测试文件已创建"
else
    print_skip "index.php 已存在，跳过"
fi

# ================================== 启动 Nginx ==================================
print_step "启动 Nginx 服务"
pkill -x nginx >/dev/null 2>&1
nginx
sleep 1
if pgrep -x "nginx" > /dev/null; then
    print_ok "Nginx 已启动"
else
    print_err "Nginx 启动失败，请检查日志"
fi

# ================================== 启动 PHP-FPM ==================================
print_step "启动 PHP-FPM 服务"
pkill -x php-fpm >/dev/null 2>&1
php-fpm
sleep 1
if pgrep -x "php-fpm" > /dev/null; then
    print_ok "PHP-FPM 已启动"
else
    print_err "PHP-FPM 启动失败"
fi

# ================================== 配置服务自启动 ===================================
print_step "配置服务自启（含关键文件检查）"
bashrc="$HOME/.bashrc"
marker_nginx="# >>> 自动启动 Nginx 和 PHP-FPM（无tput版）<<<"
sed -i "/# >>> 自动启动 Nginx 和 PHP-FPM/,/# <<< 自动启动 Nginx 和 PHP-FPM/d" "$bashrc"
if ! grep -q "$marker_nginx" "$bashrc"; then
cat >> "$bashrc" <<'EOF'

# >>> 自动启动 Nginx 和 PHP-FPM（无tput版）<<<
# 智能IP获取函数
get_smart_ip() {
    local IP=""
    IP=$(getprop dhcp.wlan0.ipaddress 2>/dev/null)
    IP=$(echo "$IP" | tr '_' '.' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' 2>/dev/null)
    if [ -n "$IP" ]; then
        echo "$IP"
        return 0
    fi

    IP=$(getprop dhcp.eth0.ipaddress 2>/dev/null)
    IP=$(echo "$IP" | tr '_' '.' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' 2>/dev/null)
    if [ -n "$IP" ]; then
        echo "$IP"
        return 0
    fi

    if command -v python >/dev/null 2>&1; then
        IP=$(python -c "import socket; s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM); s.connect(('8.8.8.8',80)); print(s.getsockname()[0]); s.close()" 2>/dev/null)
        if [ -n "$IP" ] && echo "$IP" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' >/dev/null; then
            echo "$IP"
            return 0
        fi
    fi

    if command -v curl >/dev/null 2>&1; then
        IP=$(curl -s --max-time 5 "https://api.ipify.org    " || \
             curl -s --max-time 5 "https://icanhazip.com    " | tr -d '\n' || \
             curl -s --max-time 5 "https://ip.cn/ip    " | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' 2>/dev/null)
        if [ -n "$IP" ]; then
            echo "$IP"
            return 0
        fi
    fi

    echo "127.0.0.1"
    return 0
}



# 启动Nginx
if ! pgrep -x "nginx" > /dev/null 2>&1; then
    nginx >/dev/null 2>&1
    sleep 1
    if pgrep -x "nginx" > /dev/null; then
        echo "✅ Nginx 自启成功"
    else
        echo "❌ Nginx 自启失败，手动启动：nginx"
    fi
else
    echo "✅ Nginx 已在运行"
fi

# 启动PHP-FPM
if ! pgrep -x "php-fpm" > /dev/null 2>&1; then
    php-fpm >/dev/null 2>&1
    sleep 1
    if pgrep -x "php-fpm" > /dev/null; then
        echo "✅ PHP-FPM 自启成功"
    else
        echo "❌ PHP-FPM 自启失败，手动启动：php-fpm"
    fi
else
    echo "✅ PHP-FPM 已在运行"
fi




# <<< 自动启动 Nginx 和 PHP-FPM（无tput版）<<<
EOF
    print_ok "已添加 Nginx/PHP-FPM 自启逻辑"
else
    print_skip "Nginx/PHP-FPM 自启逻辑已存在，跳过"
fi

# ================================== 关键文件初始化检查 ===================================
print_step "关键文件初始化检查（aa.json、yt001、yt.jar）"
check_critical_files_and_download








clear
show_startup_dashboard

echo -e "\n$(color 32 "✅ 所有部署与更新流程已完成")"
