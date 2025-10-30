#!/data/data/com.termux/files/usr/bin/bash
# --------------------------------------
# Termux PHP 一键安装与自动启动脚本
# 作者：木凡
# 功能：安装 PHP、创建网站目录、自动启动 PHP 服务
# --------------------------------------

# 安装 PHP
pkg install -y php

# 申请存储访问权限
termux-setup-storage

# 创建网站目录
mkdir -p /storage/emulated/0/TVBoxPhpJar/wwwroot/php

# 修改 bash.bashrc 文件，实现开机自动启动 PHP
TARGET_FILE="$PREFIX/etc/bash.bashrc"

# 如果还未添加启动命令，则写入
if ! grep -q "php -S 0.0.0.0:8081" "$TARGET_FILE"; then
    echo -e "\n# 自动启动PHP服务" >> "$TARGET_FILE"
    echo "cd /storage/emulated/0/TVBoxPhpJar/wwwroot/php && php -S 0.0.0.0:8081 &" >> "$TARGET_FILE"
    echo "echo \"服务已启动: http://\$(ip route get 1.2.3.4 | awk '{print \$7}' | head -1):8081\"" >> "$TARGET_FILE"
fi

# 立即生效
source "$TARGET_FILE"

echo "✅ 配置完成！"
echo "📁 PHP根目录: /storage/emulated/0/TVBoxPhpJar/wwwroot/php"
echo "🌐 启动地址: http://$(ip route get 1.2.3.4 | awk '{print $7}' | head -1):8081"
