#!/bin/bash
# 保存为 install.sh 然后运行: chmod +x install.sh && ./install.sh

echo -e "\033[1;36m开始安装PHP服务器...\033[0m"

# 步骤1: 安装基础软件包
echo -e "\033[1;33m[1/6] 更新软件包...\033[0m"
pkg update -y
pkg install -y php curl wget

# 步骤2: 获取存储权限
echo -e "\033[1;33m[2/6] 获取存储权限...\033[0m"
termux-setup-storage
echo "请授权存储权限，然后按回车继续..."
read

# 步骤3: 创建目录
echo -e "\033[1;33m[3/6] 创建目录结构...\033[0m"
mkdir -p ~/storage/shared/tvbox/php
mkdir -p ~/storage/shared/tvbox/logs

# 步骤4: 创建测试文件
echo -e "\033[1;33m[4/6] 创建网站文件...\033[0m"
cat > ~/storage/shared/tvbox/php/index.php << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>PHP服务器</title>
    <style>
        body { font-family: Arial; background: #f0f0f0; margin: 0; padding: 20px; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 20px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; }
        .status { background: #4CAF50; color: white; padding: 10px; border-radius: 5px; }
        .info { background: #2196F3; color: white; padding: 10px; border-radius: 5px; margin: 10px 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 PHP服务器运行成功!</h1>
        <div class="status">✅ 服务器状态: 运行中</div>
        <div class="info">
            <p><strong>访问地址:</strong> 
                <?php
                $ip = shell_exec("ifconfig wlan0 2>/dev/null | grep 'inet ' | awk '{print \$2}'");
                if(empty($ip)) $ip = '127.0.0.1';
                echo 'http://'.trim($ip).':8080';
                ?>
            </p>
            <p><strong>根目录:</strong> /storage/emulated/0/tvbox/php</p>
            <p><strong>时间:</strong> <?php echo date('Y-m-d H:i:s'); ?></p>
        </div>
        <p>将您的PHP文件放在此目录即可通过浏览器访问。</p>
    </div>
</body>
</html>
EOF

# 步骤5: 获取IP地址
echo -e "\033[1;33m[5/6] 获取IP地址...\033[0m"
IP=$(ifconfig wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}')
if [ -z "$IP" ]; then
    IP="127.0.0.1"
fi

# 步骤6: 启动服务器
echo -e "\033[1;33m[6/6] 启动PHP服务器...\033[0m"
cd ~/storage/shared/tvbox/php
pkill -f "php -S" 2>/dev/null
nohup php -S 0.0.0.0:8080 > ../logs/server.log 2>&1 &

# 等待启动
sleep 3

# 显示结果
echo -e "\033[1;32m"
echo "╔══════════════════════════════════════╗"
echo "║          安装成功!                  ║"
echo "╚══════════════════════════════════════╝"
echo -e "\033[0m"
echo -e "📱 \033[1;36m本地访问: \033[1;33mhttp://127.0.0.1:8080\033[0m"
echo -e "🌐 \033[1;36m网络访问: \033[1;33mhttp://$IP:8080\033[0m"
echo -e "📁 \033[1;36m网站目录: \033[1;33m/storage/emulated/0/tvbox/php\033[0m"
echo -e "📊 \033[1;36m日志文件: \033[1;33m/storage/emulated/0/tvbox/logs/server.log\033[0m"
echo ""
echo -e "\033[1;35m💡 提示: 服务器已在后台运行，关闭Termux后停止\033[0m"
