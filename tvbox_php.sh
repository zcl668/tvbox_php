#!/bin/bash
# ==================================
# tvbox_php 502 错误修复脚本
# ==================================

echo "🔧 开始修复 502 Bad Gateway 错误..."

# 1. 停止所有服务
echo "1. 停止服务..."
pkill -f "nginx: master" 2>/dev/null
pkill -f php-fpm 2>/dev/null
pkill -f "php-fpm: master" 2>/dev/null
sleep 2

# 2. 检查 PHP-FPM 配置
echo "2. 检查 PHP-FPM 配置..."
PHP_FPM_CONF="$PREFIX/etc/php-fpm.d/www.conf"

if [ ! -f "$PHP_FPM_CONF" ]; then
    echo "❌ PHP-FPM 配置文件不存在，重新安装..."
    pkg reinstall -y php-fpm
fi

# 3. 完全重写 PHP-FPM 配置
echo "3. 重写 PHP-FPM 配置..."
cat > "$PHP_FPM_CONF" <<'EOF'
[www]
; 监听地址和端口
listen = 127.0.0.1:9000

; 进程设置
listen.owner = $(whoami)
listen.group = $(whoami)
listen.mode = 0660

; 进程用户和组
user = $(whoami)
group = $(whoami)

; 进程管理
pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3

; 日志设置
catch_workers_output = yes
php_admin_value[error_log] = /data/data/com.termux/files/usr/var/log/php-fpm.log
php_admin_flag[log_errors] = on

; 安全设置
security.limit_extensions = .php .php3 .php4 .php5 .php7

; 性能设置
request_terminate_timeout = 60
request_slowlog_timeout = 30
slowlog = /data/data/com.termux/files/usr/var/log/php-fpm-slow.log
EOF

# 4. 创建 PHP 配置文件（如果不存在）
echo "4. 配置 PHP..."
PHP_INI="$PREFIX/etc/php.ini"
if [ -f "$PHP_INI" ]; then
    # 启用必要的扩展
    sed -i 's/;extension=curl/extension=curl/g' "$PHP_INI"
    sed -i 's/;extension=gd/extension=gd/g' "$PHP_INI"
    sed -i 's/;extension=mysqli/extension=mysqli/g' "$PHP_INI"
    sed -i 's/;extension=pdo_mysql/extension=pdo_mysql/g' "$PHP_INI"
    sed -i 's/;extension=openssl/extension=openssl/g' "$PHP_INI"
fi

# 5. 创建必要的日志目录
echo "5. 创建日志目录..."
mkdir -p "$PREFIX/var/log"
mkdir -p "$PREFIX/var/run"
touch "$PREFIX/var/log/php-fpm.log"
chmod 666 "$PREFIX/var/log/php-fpm.log"

# 6. 重写 Nginx 配置
echo "6. 重写 Nginx 配置..."
NGINX_CONF="$PREFIX/etc/nginx/nginx.conf"

cat > "$NGINX_CONF" <<'EOF'
worker_processes 1;
error_log /data/data/com.termux/files/usr/var/log/nginx/error.log;

events {
    worker_connections 1024;
}

http {
    include /data/data/com.termux/files/usr/etc/nginx/mime.types;
    default_type application/octet-stream;
    sendfile on;
    keepalive_timeout 65;
    
    access_log /data/data/com.termux/files/usr/var/log/nginx/access.log;

    server {
        listen 8081;
        server_name localhost;
        
        root /data/data/com.termux/files/home/storage/shared/zcl;
        index index.html index.htm index.php;
        
        # 错误页面
        error_page 500 502 503 504 /50x.html;
        
        location = /50x.html {
            root /data/data/com.termux/files/usr/share/nginx/html;
        }
        
        location / {
            try_files $uri $uri/ =404;
        }
        
        # PHP 处理
        location ~ \.php$ {
            try_files $uri =404;
            
            # FastCGI 配置
            fastcgi_pass 127.0.0.1:9000;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            
            # 包含标准 FastCGI 参数
            include /data/data/com.termux/files/usr/etc/nginx/fastcgi.conf;
            
            # 超时设置
            fastcgi_connect_timeout 60s;
            fastcgi_read_timeout 60s;
            fastcgi_send_timeout 60s;
        }
        
        # 拒绝访问隐藏文件
        location ~ /\. {
            deny all;
            access_log off;
            log_not_found off;
        }
    }
}
EOF

# 7. 测试 PHP-FPM 配置
echo "7. 测试 PHP-FPM..."
if php-fpm -t; then
    echo "✅ PHP-FPM 配置测试通过"
else
    echo "❌ PHP-FPM 配置测试失败"
fi

# 8. 测试 Nginx 配置
echo "8. 测试 Nginx..."
if nginx -t; then
    echo "✅ Nginx 配置测试通过"
else
    echo "❌ Nginx 配置测试失败"
    # 显示详细错误
    nginx -t
fi

# 9. 启动 PHP-FPM（详细模式）
echo "9. 启动 PHP-FPM..."
php-fpm --fpm-config "$PREFIX/etc/php-fpm.conf" -c "$PREFIX/etc/php.ini" -F &

echo "等待 PHP-FPM 启动..."
sleep 3

# 10. 检查 PHP-FPM 是否在运行
if pgrep -f "php-fpm" >/dev/null; then
    echo "✅ PHP-FPM 启动成功"
    echo "PHP-FPM 进程:"
    pgrep -f "php-fpm"
else
    echo "❌ PHP-FPM 启动失败"
    echo "检查日志: $PREFIX/var/log/php-fpm.log"
    tail -20 "$PREFIX/var/log/php-fpm.log"
fi

# 11. 检查端口 9000 是否在监听
echo "检查端口监听状态..."
if netstat -tulpn 2>/dev/null | grep :9000; then
    echo "✅ PHP-FPM 正在监听 9000 端口"
else
    echo "❌ PHP-FPM 未监听 9000 端口"
    echo "尝试替代检查..."
    if ss -tulpn 2>/dev/null | grep :9000; then
        echo "✅ 使用 ss 命令检测到端口"
    else
        echo "❌ 端口 9000 未监听"
    fi
fi

# 12. 启动 Nginx
echo "10. 启动 Nginx..."
nginx

sleep 2

# 13. 检查 Nginx
if pgrep -f "nginx: master" >/dev/null; then
    echo "✅ Nginx 启动成功"
else
    echo "❌ Nginx 启动失败"
fi

# 14. 最终测试
echo "11. 进行最终测试..."
echo "等待服务完全启动..."
sleep 3

echo "--- 服务状态检查 ---"
echo "Nginx 进程: $(pgrep -f 'nginx' | wc -l)"
echo "PHP-FPM 进程: $(pgrep -f 'php-fpm' | wc -l)"

# 测试访问
echo "--- 访问测试 ---"
if curl -s -I http://127.0.0.1:8081/ 2>/dev/null | head -1 | grep -q "200\|302"; then
    echo "✅ 网站可正常访问"
else
    echo "❌ 网站访问失败"
    echo "响应: $(curl -s -I http://127.0.0.1:8081/ 2>/dev/null | head -1)"
fi

echo ""
echo "🎊 修复完成！"
echo "📍 访问地址: http://127.0.0.1:8081"
echo ""
echo "📋 如果仍有问题，请检查："
echo "1. PHP-FPM 日志: tail -f $PREFIX/var/log/php-fpm.log"
echo "2. Nginx 错误日志: tail -f $PREFIX/var/log/nginx/error.log"
echo "3. 端口监听: netstat -tulpn | grep :9000"
