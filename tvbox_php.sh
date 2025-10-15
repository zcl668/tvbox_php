#!/bin/bash
# ==================================
# tvbox_php 一键安装脚本（Termux + Nginx + PHP 环境管理）
# 端口：8081
# 网站目录：~/storage/shared/zcl  (更安全的路径)
# ==================================

WEB_DIR="$HOME/storage/shared/zcl"
BASHRC="$HOME/.bashrc"
PORT=8081

ok() { echo -e "✅ $1"; }
err() { echo -e "❌ $1"; }
skip() { echo -e "⏭️ $1"; }
step() { echo -e "\n🧩 $1"; }

# 检查是否在 Termux 环境中
if [ ! -d "$PREFIX" ] || [ -z "$(which termux-setup-storage 2>/dev/null)" ]; then
    echo "错误：此脚本只能在 Termux 环境中运行"
    exit 1
fi

# 智能安装
step "检查并安装必要组件"
pkg update -y
pkg upgrade -y
REQUIRED_PKGS=("nginx" "php" "php-fpm" "curl" "psmisc")
for pkg in "${REQUIRED_PKGS[@]}"; do
    if dpkg -s "$pkg" &>/dev/null; then
        skip "$pkg 已安装"
    else
        echo "正在安装 $pkg ..."
        pkg install -y "$pkg" && ok "$pkg 安装完成" || err "$pkg 安装失败"
    fi
done

# 请求存储权限
step "请求存储权限"
if [ ! -d "$HOME/storage/shared" ]; then
    termux-setup-storage
    sleep 2
fi

# 创建必要的目录
step "创建必要的目录"
mkdir -p "$PREFIX/var/log/nginx"
mkdir -p "$PREFIX/var/run"
mkdir -p "$WEB_DIR"

# 配置 Nginx
step "配置 Nginx"
NGINX_CONF="$PREFIX/etc/nginx/nginx.conf"
if [ -f "$NGINX_CONF" ]; then
    mv "$NGINX_CONF" "$NGINX_CONF.bak"
fi

cat > "$NGINX_CONF" <<EOF
worker_processes 1;
error_log $PREFIX/var/log/nginx/error.log;
pid $PREFIX/var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include $PREFIX/etc/nginx/mime.types;
    default_type application/octet-stream;
    sendfile on;
    keepalive_timeout 65;
    
    # 访问日志
    access_log $PREFIX/var/log/nginx/access.log;
    
    server {
        listen $PORT;
        server_name localhost;
        root $WEB_DIR;
        index index.html index.php;
        
        # 防止隐藏文件访问
        location ~ /\. {
            deny all;
        }
        
        location / {
            try_files \$uri \$uri/ /index.php?\$args;
        }
        
        location ~ \.php\$ {
            fastcgi_pass 127.0.0.1:9000;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
            include $PREFIX/etc/nginx/fastcgi.conf;
        }
    }
}
EOF

# 检查 nginx 配置语法
if nginx -t >/dev/null 2>&1; then
    ok "Nginx 配置语法正确"
else
    err "Nginx 配置有误，显示详细错误："
    nginx -t
    exit 1
fi

# 配置 PHP-FPM
step "配置 PHP-FPM"
PHP_FPM_CONF="$PREFIX/etc/php-fpm.d/www.conf"
if [ -f "$PHP_FPM_CONF" ]; then
    # 备份原配置
    cp "$PHP_FPM_CONF" "$PHP_FPM_CONF.bak"
    
    # 修改 PHP-FPM 配置
    sed -i 's|^listen = .*|listen = 127.0.0.1:9000|' "$PHP_FPM_CONF"
    sed -i 's|^;listen.owner = .*|listen.owner = $(whoami)|' "$PHP_FPM_CONF"
    sed -i 's|^;listen.group = .*|listen.group = $(whoami)|' "$PHP_FPM_CONF"
    sed -i 's|^;listen.mode = .*|listen.mode = 0660|' "$PHP_FPM_CONF"
    sed -i 's|^user = .*|user = $(whoami)|' "$PHP_FPM_CONF"
    sed -i 's|^group = .*|group = $(whoami)|' "$PHP_FPM_CONF"
    
    ok "PHP-FPM 配置完成"
else
    err "PHP-FPM 配置文件不存在: $PHP_FPM_CONF"
    echo "尝试重新安装 php-fpm..."
    pkg reinstall -y php-fpm
fi

# 创建网站目录和测试页
step "创建网站目录与测试页面"
if [ ! -f "$WEB_DIR/index.php" ]; then
    cat > "$WEB_DIR/index.php" <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>TVBox PHP 服务</title>
    <meta charset="utf-8">
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { background: white; padding: 20px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; }
        .status { padding: 10px; background: #d4edda; color: #155724; border-radius: 5px; margin: 10px 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🎉 TVBox PHP 服务运行成功！</h1>
        <div class="status">
            ✅ PHP 环境正常工作<br>
            ✅ Nginx 服务器正常运行<br>
            📍 端口：8081<br>
            📁 网站目录：<?php echo __DIR__; ?>
        </div>
        <h2>PHP 信息：</h2>
        <?php 
        echo '<p>PHP 版本: ' . PHP_VERSION . '</p >';
        echo '<p>服务器软件: ' . $_SERVER['SERVER_SOFTWARE'] . '</p >';
        phpinfo(); 
        ?>
    </div>
</body>
</html>
EOF
    ok "测试页面已创建：$WEB_DIR/index.php"
else
    skip "测试页面已存在"
fi

# 设置目录权限
step "设置目录权限"
chmod -R 755 "$WEB_DIR"
find "$WEB_DIR" -type f -exec chmod 644 {} \;

# 开机自启配置
step "配置开机自启"
START_SCRIPT="$HOME/.termux/boot/tvbox_php.sh"
mkdir -p "$HOME/.termux/boot"

cat > "$START_SCRIPT" <<EOF
#!/bin/bash
# 自动启动 tvbox_php 服务
sleep 5
pkill -f "nginx: master" >/dev/null 2>&1
pkill -f php-fpm >/dev/null 2>&1
nginx -c $PREFIX/etc/nginx/nginx.conf
php-fpm --fpm-config $PREFIX/etc/php-fpm.conf --php-ini $PREFIX/etc/php.ini
echo "✅ tvbox_php 服务已启动: http://127.0.0.1:$PORT"
EOF

chmod +x "$START_SCRIPT"
ok "开机自启脚本已创建: $START_SCRIPT"

# 添加到 bashrc 用于手动启动
if ! grep -q "tvbox_php" "$BASHRC"; then
    cat >> "$BASHRC" <<EOF

# tvbox_php 服务快捷命令
alias tvbox-start='pkill -f "nginx: master" >/dev/null 2>&1; pkill -f php-fpm >/dev/null 2>&1; nginx && php-fpm && echo "✅ tvbox_php 服务已启动: http://127.0.0.1:$PORT"'
alias tvbox-stop='pkill -f "nginx: master" >/dev/null 2>&1; pkill -f php-fpm >/dev/null 2>&1; echo "🛑 tvbox_php 服务已停止"'
alias tvbox-status='pgrep -f "nginx: master" >/dev/null && echo "✅ Nginx 运行中" || echo "❌ Nginx 未运行"; pgrep -f php-fpm >/dev/null && echo "✅ PHP-FPM 运行中" || echo "❌ PHP-FPM 未运行"'
alias tvbox-restart='tvbox-stop; sleep 2; tvbox-start'
EOF
    ok "快捷命令已添加到 bashrc"
else
    skip "快捷命令已存在"
fi

# 启动服务
step "启动 Nginx + PHP-FPM"
pkill -f "nginx: master" >/dev/null 2>&1
pkill -f php-fpm >/dev/null 2>&1
sleep 2

# 启动服务
nginx && php-fpm

# 检查服务状态
sleep 3
echo -e "\n--- 服务启动状态检查 ---"
if pgrep -f "nginx: master" >/dev/null; then
    ok "Nginx 启动成功"
else
    err "Nginx 启动失败"
    echo "请检查错误日志: $PREFIX/var/log/nginx/error.log"
fi

if pgrep -f php-fpm >/dev/null; then
    ok "PHP-FPM 启动成功"
else
    err "PHP-FPM 启动失败"
fi

echo -e "\n🎊 安装完成！"
echo "📍 访问地址: http://127.0.0.1:$PORT"
echo "📁 网站目录: $WEB_DIR"
echo "⚡ 快捷命令: tvbox-start, tvbox-stop, tvbox-status, tvbox-restart"

# 菜单管理
while true; do
    echo -e "\n========= tvbox_php 服务控制菜单 ========="
    echo "1) 启动 Nginx + PHP-FPM"
    echo "2) 停止 Nginx + PHP-FPM"
    echo "3) 重启服务"
    echo "4) 查看状态"
    echo "5) 打开浏览器"
    echo "6) 查看日志"
    echo "7) 退出菜单"
    echo "8) 完全退出并停止服务"
    echo "===================================="
    read -p "请输入选项 [1-8]: " choice

    case "$choice" in
        1)
            pkill -f "nginx: master" >/dev/null 2>&1
            pkill -f php-fpm >/dev/null 2>&1
            nginx && php-fpm
            sleep 2
            ok "服务已启动: http://127.0.0.1:$PORT"
            ;;
        2)
            pkill -f "nginx: master" >/dev/null 2>&1
            pkill -f php-fpm >/dev/null 2>&1
            ok "服务已停止"
            ;;
        3)
            pkill -f "nginx: master" >/dev/null 2>&1
            pkill -f php-fpm >/dev/null 2>&1
            sleep 2
            nginx && php-fpm
            sleep 2
            ok "服务已重启: http://127.0.0.1:$PORT"
            ;;
        4)
            echo -e "\n--- 当前服务状态 ---"
            if pgrep -f "nginx: master" >/dev/null; then
                ok "Nginx 正在运行 (PID: $(pgrep -f "nginx: master"))"
            else
                err "Nginx 未运行"
            fi
            
            if pgrep -f php-fpm >/dev/null; then
                ok "PHP-FPM 正在运行 (PID: $(pgrep -f php-fpm))"
            else
                err "PHP-FPM 未运行"
            fi
            
            # 测试 PHP 服务
            if curl -s http://127.0.0.1:$PORT >/dev/null; then
                ok "Web 服务可正常访问"
            else
                err "Web 服务无法访问"
            fi
            ;;
        5)
            termux-open-url "http://127.0.0.1:$PORT"
            ;;
        6)
            echo -e "\n--- 最近错误日志 ---"
            tail -10 "$PREFIX/var/log/nginx/error.log"
            ;;
        7)
            echo "退出菜单，服务继续运行"
            break
            ;;
        8)
            echo "停止所有服务并退出..."
            pkill -f "nginx: master" >/dev/null 2>&1
            pkill -f php-fpm >/dev/null 2>&1
            exit 0
            ;;
        *)
            echo "无效输入，请输入 1-8"
            ;;
    esac
done
