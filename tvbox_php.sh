#!/bin/bash
# ==================================
# tvbox_php 403 错误修复脚本
# ==================================

WEB_DIR="$HOME/storage/shared/zcl"
PORT=8081

echo "🔧 开始修复 403 错误..."

# 1. 重新创建网站目录（确保权限正确）
echo "1. 设置目录权限..."
rm -rf "$WEB_DIR"
mkdir -p "$WEB_DIR"
chmod 755 "$WEB_DIR"

# 2. 创建测试文件
echo "2. 创建测试文件..."
cat > "$WEB_DIR/index.php" <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>TVBox PHP 测试</title>
    <meta charset="utf-8">
</head>
<body>
    <h1>🎉 TVBox PHP 服务运行成功！</h1>
    <p>✅ 如果看到此页面，说明 403 错误已修复</p>
    <p>📌 PHP 版本: <?php echo PHP_VERSION; ?></p>
    <p>🕒 服务器时间: <?php echo date('Y-m-d H:i:s'); ?></p>
    
    <h2>环境信息：</h2>
    <ul>
        <li>当前用户: <?php echo exec('whoami'); ?></li>
        <li>文档根目录: <?php echo $_SERVER['DOCUMENT_ROOT']; ?></li>
        <li>脚本路径: <?php echo __FILE__; ?></li>
    </ul>
    
    <h2>PHP 配置测试：</h2>
    <?php
    // 测试 PHP 功能
    echo "<p>PHP 基本功能: " . (function_exists('phpinfo') ? '✅ 正常' : '❌ 异常') . "</p>";
    echo "<p>文件读写: " . (is_writable(__FILE__) ? '✅ 可写' : '❌ 不可写') . "</p>";
    
    // 显示目录内容
    echo "<h3>网站目录文件列表：</h3>";
    $files = scandir(__DIR__);
    echo "<ul>";
    foreach ($files as $file) {
        if ($file != "." && $file != "..") {
            $filepath = __DIR__ . '/' . $file;
            $filetype = is_dir($filepath) ? "📁" : "📄";
            $perms = substr(sprintf('%o', fileperms($filepath)), -4);
            echo "<li>$filetype $file (权限: $perms)</li>";
        }
    }
    echo "</ul>";
    ?>
</body>
</html>
EOF

chmod 644 "$WEB_DIR/index.php"

# 3. 创建简单的 HTML 测试页（避免 PHP 问题）
cat > "$WEB_DIR/index.html" <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>TVBox HTML 测试</title>
    <meta charset="utf-8">
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .success { color: green; font-size: 24px; }
        .info { background: #f0f0f0; padding: 20px; border-radius: 10px; }
    </style>
</head>
<body>
    <h1 class="success">✅ HTML 页面可访问！</h1>
    <p>这说明 Nginx 服务器工作正常。</p>
    
    <div class="info">
        <h2>下一步测试：</h2>
        <p>请访问 <a href="/index.php">PHP 测试页面</a> 检查 PHP 是否工作。</p>
        <p>如果 PHP 页面仍然 403，请检查 PHP-FPM 配置。</p>
    </div>
</body>
</html>
EOF

chmod 644 "$WEB_DIR/index.html"

# 4. 修复 Nginx 配置
echo "3. 修复 Nginx 配置..."
NGINX_CONF="$PREFIX/etc/nginx/nginx.conf"

cat > "$NGINX_CONF" <<EOF
worker_processes 1;
error_log $PREFIX/var/log/nginx/error.log;

events {
    worker_connections 1024;
}

http {
    include $PREFIX/etc/nginx/mime.types;
    default_type application/octet-stream;
    sendfile on;
    keepalive_timeout 65;
    client_max_body_size 10M;
    
    access_log $PREFIX/var/log/nginx/access.log;

    server {
        listen $PORT;
        server_name localhost;
        
        # 重要：网站根目录
        root $WEB_DIR;
        index index.html index.htm index.php;
        
        # 关闭严格目录权限检查
        disable_symlinks off;
        
        # 允许访问所有文件
        location / {
            try_files \$uri \$uri/ /index.php?\$query_string;
        }
        
        # PHP 配置
        location ~ \.php\$ {
            try_files \$uri =404;
            fastcgi_pass 127.0.0.1:9000;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
            include $PREFIX/etc/nginx/fastcgi.conf;
        }
        
        # 拒绝访问隐藏文件
        location ~ /\. {
            deny all;
        }
    }
}
EOF

# 5. 修复 PHP-FPM 配置
echo "4. 修复 PHP-FPM 配置..."
PHP_FPM_CONF="$PREFIX/etc/php-fpm.d/www.conf"

if [ -f "$PHP_FPM_CONF" ]; then
    # 备份原配置
    cp "$PHP_FPM_CONF" "$PHP_FPM_CONF.bak"
    
    # 获取当前用户名
    CURRENT_USER=$(whoami)
    
    # 修复配置
    sed -i 's|^listen = .*|listen = 127.0.0.1:9000|' "$PHP_FPM_CONF"
    sed -i "s|^user = .*|user = $CURRENT_USER|" "$PHP_FPM_CONF"
    sed -i "s|^group = .*|group = $CURRENT_USER|" "$PHP_FPM_CONF"
    sed -i 's|^;listen.owner = .*|listen.owner = $(whoami)|' "$PHP_FPM_CONF"
    sed -i 's|^;listen.group = .*|listen.group = $(whoami)|' "$PHP_FPM_CONF"
    sed -i 's|^;listen.mode = .*|listen.mode = 0660|' "$PHP_FPM_CONF"
    
    echo "✅ PHP-FPM 配置已修复"
else
    echo "❌ PHP-FPM 配置文件不存在"
fi

# 6. 设置正确的所有权（在 Termux 中很重要）
echo "5. 设置文件所有权..."
chown -R $(whoami):$(whoami) "$WEB_DIR"

# 7. 检查配置
echo "6. 检查 Nginx 配置..."
if nginx -t; then
    echo "✅ Nginx 配置语法正确"
else
    echo "❌ Nginx 配置有错误"
    exit 1
fi

# 8. 重启服务
echo "7. 重启服务..."
pkill -f "nginx: master" 2>/dev/null
pkill -f php-fpm 2>/dev/null
sleep 2

nginx
php-fpm

sleep 2

# 9. 检查服务状态
echo "8. 检查服务状态..."
echo "--- Nginx 进程 ---"
pgrep -f nginx

echo "--- PHP-FPM 进程 ---" 
pgrep -f php-fpm

echo "--- 目录权限 ---"
ls -la "$WEB_DIR"

# 10. 测试访问
echo "9. 测试访问..."
echo "等待服务启动..."
sleep 3

if curl -s http://127.0.0.1:$PORT/index.html >/dev/null; then
    echo "✅ HTML 页面可访问"
else
    echo "❌ HTML 页面访问失败"
fi

if curl -s http://127.0.0.1:$PORT/index.php >/dev/null; then
    echo "✅ PHP 页面可访问"
else
    echo "❌ PHP 页面访问失败"
fi

echo ""
echo "🎊 修复完成！"
echo "📍 请访问以下地址测试："
echo "   HTML 页面: http://127.0.0.1:$PORT/index.html"
echo "   PHP 页面:  http://127.0.0.1:$PORT/index.php"
echo ""
echo "如果仍有问题，请查看错误日志："
echo "tail -f $PREFIX/var/log/nginx/error.log"
