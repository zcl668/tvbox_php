#!/bin/bash

# 彩色输出定义
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m' # 无颜色

# 显示彩色横幅
show_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║             TERMUX PHP 服务器管理器          ║"
    echo "║               彩色增强版 v2.0               ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 检查并安装必要软件
check_dependencies() {
    echo -e "${YELLOW}[信息] 检查依赖包...${NC}"
    
    local pkgs=("php" "curl" "wget")
    local missing=()
    
    for pkg in "${pkgs[@]}"; do
        if ! pkg list-installed | grep -q $pkg; then
            missing+=($pkg)
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        echo -e "${YELLOW}[安装] 安装缺失包: ${missing[*]}${NC}"
        pkg update -y
        pkg install -y "${missing[@]}"
        echo -e "${GREEN}[成功] 所有依赖包已安装${NC}"
    else
        echo -e "${GREEN}[成功] 所有依赖包已就绪${NC}"
    fi
}

# 获取存储权限
get_storage_permission() {
    echo -e "${YELLOW}[信息] 请求存储权限...${NC}"
    termux-setup-storage
    
    # 等待用户授权
    sleep 3
    
    if [ -d "/storage/emulated/0" ]; then
        echo -e "${GREEN}[成功] 存储权限获取成功${NC}"
        return 0
    else
        echo -e "${RED}[错误] 存储权限获取失败${NC}"
        return 1
    fi
}

# 创建目录结构
create_directories() {
    local base_dir="/storage/emulated/0/tvbox"
    
    echo -e "${YELLOW}[信息] 创建目录结构...${NC}"
    
    mkdir -p "$base_dir/php"
    mkdir -p "$base_dir/logs"
    mkdir -p "$base_dir/backups"
    
    # 创建默认index.php文件
    if [ ! -f "$base_dir/php/index.php" ]; then
        cat > "$base_dir/php/index.php" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Termux PHP服务器</title>
    <style>
        body { 
            font-family: Arial, sans-serif; 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            margin: 0; padding: 20px; color: white;
        }
        .container { 
            max-width: 800px; 
            margin: 0 auto; 
            background: rgba(255,255,255,0.1); 
            padding: 30px; 
            border-radius: 15px;
            backdrop-filter: blur(10px);
        }
        h1 { color: #ffeb3b; text-align: center; }
        .status { 
            background: rgba(0,0,0,0.3); 
            padding: 15px; 
            border-radius: 8px; 
            margin: 10px 0;
        }
        .info { color: #4caf50; }
        .warning { color: #ff9800; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🎉 PHP服务器运行成功！</h1>
        <div class="status">
            <p class="info">✅ 服务器状态: <strong>运行中</strong></p>
            <p>📁 根目录: /storage/emulated/0/tvbox/php</p>
            <p>🌐 访问地址: 
                <?php 
                    $ip = shell_exec("ip route get 1.2.3.4 | awk '{print $7}' | head -1");
                    echo "http://".trim($ip).":8081";
                ?>
            </p>
            <p>🕐 启动时间: <?php echo date('Y-m-d H:i:s'); ?></p>
        </div>
        <p class="warning">💡 提示: 将您的PHP文件放在此目录即可通过浏览器访问</p>
    </div>
</body>
</html>
EOF
        echo -e "${GREEN}[成功] 默认index.php已创建${NC}"
    fi
    
    echo -e "${GREEN}[成功] 目录结构创建完成${NC}"
}

# 获取本机IP地址
get_ip_address() {
    local ip=$(ip route get 1.2.3.4 2>/dev/null | awk '{print $7}' | head -1)
    if [ -z "$ip" ]; then
        ip="127.0.0.1"
    fi
    echo $ip
}

# 启动PHP服务
start_php_server() {
    echo -e "${YELLOW}[信息] 启动PHP服务器...${NC}"
    
    local php_dir="/storage/emulated/0/tvbox/php"
    local log_dir="/storage/emulated/0/tvbox/logs"
    local ip=$(get_ip_address)
    
    # 检查是否已在运行
    if pgrep -f "php -S" > /dev/null; then
        echo -e "${YELLOW}[警告] PHP服务已在运行，先停止旧进程...${NC}"
        pkill -f "php -S"
        sleep 2
    fi
    
    # 启动PHP服务
    cd "$php_dir"
    nohup php -S "${ip}:8081" > "$log_dir/php_server.log" 2>&1 &
    
    local pid=$!
    sleep 2
    
    if ps -p $pid > /dev/null; then
        echo -e "${GREEN}[成功] PHP服务器已启动!${NC}"
        echo -e "${CYAN}📱 本地访问: http://127.0.0.1:8081${NC}"
        echo -e "${CYAN}🌐 网络访问: http://${ip}:8081${NC}"
        echo -e "${CYAN}📁 根目录: $php_dir${NC}"
        echo -e "${CYAN}📊 日志文件: $log_dir/php_server.log${NC}"
    else
        echo -e "${RED}[错误] PHP服务器启动失败${NC}"
        return 1
    fi
}

# 停止PHP服务
stop_php_server() {
    echo -e "${YELLOW}[信息] 停止PHP服务器...${NC}"
    
    if pgrep -f "php -S" > /dev/null; then
        pkill -f "php -S"
        echo -e "${GREEN}[成功] PHP服务器已停止${NC}"
    else
        echo -e "${YELLOW}[信息] 没有找到运行的PHP服务${NC}"
    fi
}

# 显示服务状态
show_status() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║                 服务状态信息                 ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    if pgrep -f "php -S" > /dev/null; then
        local ip=$(get_ip_address)
        echo -e "${GREEN}✅ PHP服务器状态: 运行中${NC}"
        echo -e "${BLUE}🌐 访问地址
