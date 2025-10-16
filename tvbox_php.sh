#!/bin/bash
echo "🔄 使用 PHP 内置服务器作为备用方案..."

# 停止现有服务
pkill -f nginx
pkill -f php-fpm

# 启动 PHP 内置服务器
cd /storage/emulated/0/zcl
nohup php -S 0.0.0.0:8081 > $PREFIX/var/log/php-builtin-server.log 2>&1 &

echo "等待服务器启动..."
sleep 3

if pgrep -f "php -S" >/dev/null; then
    echo "✅ PHP 内置服务器启动成功！"
    echo "📍 访问地址: http://127.0.0.1:8081"
    echo "📋 日志文件: $PREFIX/var/log/php-builtin-server.log"
    
    # 测试访问
    if curl -s http://127.0.0.1:8081/index.php >/dev/null; then
        echo "🎉 PHP 页面可以正常访问了！"
    else
        echo "❌ 仍然无法访问，请检查日志"
        tail -10 $PREFIX/var/log/php-builtin-server.log
    fi
else
    echo "❌ PHP 内置服务器启动失败"
    tail -10 $PREFIX/var/log/php-builtin-server.log
fi
