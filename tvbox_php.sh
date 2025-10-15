#!/bin/bash
# ==================================
# PHP-FPM 完全修复脚本
# ==================================

echo "🔧 彻底修复 PHP-FPM 连接问题..."

# 1. 完全停止所有服务
echo "1. 完全停止服务..."
pkill -f "nginx: master" 2>/dev/null
pkill -f php-fpm 2>/dev/null
pkill -f "php-fpm: master" 2>/dev/null
sleep 3

# 2. 检查并重新安装 PHP-FPM
echo "2. 检查 PHP-FPM 安装..."
if ! pkg list-installed | grep -q php-fpm; then
    echo "❌ PHP-FPM 未安装，重新安装..."
    pkg install -y php-fpm
else
    echo "✅ PHP-FPM 已安装"
fi

# 3. 创建完整的 PHP-FPM 配置
echo "3. 创建完整的 PHP-FPM 配置..."
PHP_FPM_DIR="$PREFIX/etc/php-fpm.d"
mkdir -p "$PHP_FPM_DIR"

# 主配置文件
cat > "$PREFIX/etc/php-fpm.conf" <<'EOF'
[global]
pid = /data/data/com.termux/files/usr/var/run/php-fpm.pid
error_log = /data/data/com.termux/files/usr/var/log/php-fpm.log
log_level = notice
emergency_restart_threshold = 10
emergency_restart_interval = 1m
process_control_timeout = 10s
daemonize = yes

include=/data/data/com.termux/files/usr/etc/php-fpm.d/*.conf
EOF

# WWW 池配置
cat > "$PHP_FPM_DIR/www.conf" <<'EOF'
[www]
; 监听设置
listen = 127.0.0.1:9000
listen.backlog = 511
listen.allowed_clients = 127.0.0.1

; 进程用户
user = u0_a119
group = u0_a119

; 进程管理
pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
pm.max_requests = 500

; 权限设置
listen.owner = u0_a119
listen.group = u0_a119
listen.mode = 0660

; 日志设置
catch_workers_output = yes
php_admin_value[error_log] = /data/data/com.termux/files/usr/var/log/php-fpm-www.log
php_admin_flag[log_errors] = on

; 环境设置
env[HOSTNAME] = $HOSTNAME
env[PATH] = /data/data/com.termux/files/usr/bin:/data/data/com.termux/files/usr/bin/applets
env[TMP] = /data/data/com.termux/files/usr/tmp
env[TMPDIR] = /data/data/com.termux/files/usr/tmp
env[TEMP] = /data/data/com.termux/files/usr/tmp

; 安全设置
security.limit_extensions = .php .php3 .php4 .php5 .php7 .phar

; 性能设置
request_terminate_timeout = 60
request_slowlog_timeout = 30
slowlog = /data/data/com.termux/files/usr/var/log/php-fpm-slow.log

; PHP 设置
php_flag[display_errors] = on
php_value[error_reporting] = E_ALL & ~E_DEPRECATED & ~E_STRICT
php_admin_value[memory_limit] = 128M
php_admin_value[max_execution_time] = 30
php_admin_value[post_max_size] = 8M
php_admin_value[upload_max_filesize] = 2M
EOF

# 4. 创建必要的目录和文件
echo "4. 创建必要的目录..."
mkdir -p "$PREFIX/var/log"
mkdir -p "$PREFIX/var/run"
mkdir -p "$PREFIX/tmp"

touch "$PREFIX/var/log/php-fpm.log"
touch "$PREFIX/var/log/php-fpm-www.log"
touch "$PREFIX/var/run/php-fpm.pid"

chmod 644 "$PREFIX/var/log/php-fpm.log"
chmod 644 "$PREFIX/var/log/php-fpm-www.log"

# 5. 修复 PHP 配置
echo "5. 修复 PHP 配置..."
PHP_INI="$PREFIX/etc/php.ini"
if [ -f "$PHP_INI" ]; then
    # 启用必要的扩展
    sed -i 's/;extension=curl/extension=curl/g' "$PHP_INI"
    sed -i 's/;extension=gd/extension=gd/g' "$PHP_INI"
    sed -i 's/;extension=mysqli/extension=mysqli/g' "$PHP_INI"
    sed -i 's/;extension=pdo_mysql/extension=pdo_mysql/g' "$PHP_INI"
    sed -i 's/;extension=openssl/extension=openssl/g' "$PHP_INI"
    sed -i 's/;extension=sqlite3/extension=sqlite3/g' "$PHP_INI"
    
    # 错误显示设置
    sed -i 's/display_errors = Off/display_errors = On/g' "$PHP_INI"
    sed -i 's/error_reporting = .*/error_reporting = E_ALL/g' "$PHP_INI"
fi

# 6. 测试 PHP-FPM 配置
echo "6. 测试 PHP-FPM 配置..."
if php-fpm -t; then
    echo "✅ PHP-FPM 配置测试通过"
else
    echo "❌ PHP-FPM 配置测试失败，显示详细错误:"
    php-fpm -t
fi

# 7. 启动 PHP-FPM（详细调试）
echo "7. 启动 PHP-FPM..."
# 先检查端口是否被占用
if netstat -tulpn 2>/dev/null | grep :9000; then
    echo "⚠️  端口 9000 已被占用，清理..."
    fuser -k 9000/tcp 2>/dev/null
    sleep 2
fi

# 启动 PHP-FPM 并记录输出
php-fpm --fpm-config "$PREFIX/etc/php-fpm.conf" -c "$PREFIX/etc/php.ini" -F &

echo "等待 PHP-FPM 启动..."
sleep 5

# 8. 检查 PHP-FPM 状态
echo "8. 检查 PHP-FPM 状态..."
echo "--- 进程检查 ---"
pgrep -af php-fpm

echo "--- 端口检查 ---"
if netstat -tulpn 2>/dev/null | grep :9000; then
    echo "✅ PHP-FPM 正在监听 9000 端口"
else
    echo "❌ PHP-FPM 未监听 9000 端口"
    echo "尝试使用 ss 命令检查:"
    ss -tulpn 2>/dev/null | grep :9000 || echo "❌ 未找到 9000 端口监听"
fi

# 9. 检查日志
echo "--- 日志检查 ---"
if [ -f "$PREFIX/var/log/php-fpm.log" ]; then
    echo "PHP-FPM 主日志:"
    tail -5 "$PREFIX/var/log/php-fpm.log"
fi

if [ -f "$PREFIX/var/log/php-fpm-www.log" ]; then
    echo "PHP-FPM WWW 池日志:"
    tail -5 "$PREFIX/var/log/php-fpm-www.log"
fi

# 10. 启动 Nginx
echo "9. 启动 Nginx..."
nginx -t && nginx

sleep 2

# 11. 最终测试
echo "10. 最终测试..."
echo "--- 服务状态 ---"
echo "Nginx: $(pgrep -f 'nginx: master' >/dev/null && echo '✅ 运行中' || echo '❌ 未运行')"
echo "PHP-FPM: $(pgrep -f 'php-fpm: master' >/dev/null && echo '✅ 运行中' || echo '❌ 未运行')"

echo "--- 连接测试 ---"
if curl -s http://127.0.0.1:8081/index.html >/dev/null; then
    echo "✅ HTML 页面访问正常"
else
    echo "❌ HTML 页面访问失败"
fi

if curl -s http://127.0.0.1:8081/index.php >/dev/null; then
    echo "✅ PHP 页面访问正常"
else
    RESPONSE=$(curl -s -I http://127.0.0.1:8081/index.php 2>/dev/null | head -1)
    echo "❌ PHP 页面访问失败: $RESPONSE"
fi

echo ""
echo "🎊 修复完成！"
