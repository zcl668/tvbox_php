#!/bin/bash
# ===============================================
# 精简面板脚本 - Termux/安卓环境
===============================================

PREFIX=$HOME
WEB_DIR="/storage/emulated/0/lz"

# 彩色输出函数
color() { echo -e "\033[$1m$2\033[0m"; }
print_ok() { echo -e "$(color 32 "[✔]") $1"; }
print_warn() { echo -e "$(color 33 "[!]") $1"; }
print_err() { echo -e "$(color 31 "[✘]") $1"; }
print_skip() { echo -e "$(color 36 "[→]") $1"; }

# ================== Nginx 配置 ==================
NGINX_CONF="$PREFIX/etc/nginx/nginx.conf"
if [ ! -f "$NGINX_CONF" ] || ! grep -q "root $WEB_DIR;" "$NGINX_CONF"; then
    cat > "$NGINX_CONF" <<EOF
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
        listen 8081 default_server;
        server_name localhost;
        charset utf-8;
        root $WEB_DIR;
        index index.html index.htm index.php;

        location / {
            try_files \$uri \$uri/ \$uri.php?\$args;
        }

        error_page 500 502 503 504 /50x.html;
        location = /50x.html {
            root $WEB_DIR;
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
    print_ok "Nginx 主配置完成（端口8081）"
else
    print_skip "Nginx 主配置已存在且有效，跳过"
fi

# ================== 启动 Nginx ==================
echo "启动 Nginx..."
nginx -c "$NGINX_CONF"
print_ok "网站已启动，访问：http://localhost:8081/index.php"

# ================== 面板显示 ==================
echo -e "  🔹 网站目录: $(color 36 "$WEB_DIR")"
echo -e "  📌 测试页面访问: http://localhost:8081/index.php"

# ================== 后续功能保留 ==================
# 这里可以添加你其他保留的功能，例如：
# - 文件管理
# - 下载功能
# - PHP 脚本执行等
