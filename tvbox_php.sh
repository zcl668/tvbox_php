#!/bin/bash

# 彩色输出定义
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# 显示横幅
show_banner() {
    clear
    echo -e "${PURPLE}"
    echo "████████╗███████╗██████╗ ███╗   ███╗██╗   ██╗██╗  ██╗"
    echo "╚══██╔══╝██╔════╝██╔══██╗████╗ ████║██║   ██║╚██╗██╔╝"
    echo "   ██║   █████╗  ██████╔╝██╔████╔██║██║   ██║ ╚███╔╝ "
    echo "   ██║   ██╔══╝  ██╔══██╗██║╚██╔╝██║██║   ██║ ██╔██╗ "
    echo "   ██║   ███████╗██║  ██║██║ ╚═╝ ██║╚██████╔╝██╔╝ ██╗"
    echo "   ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═╝"
    echo -e "${CYAN}"
    echo "              PHP 服务器一键安装版 v3.0"
    echo "                 支持开机自启动"
    echo -e "${NC}"
    echo -e "${YELLOW}=================================================${NC}"
}

# 日志记录
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error_log() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] 错误: $1${NC}"
}

warning_log() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] 警告: $1${NC}"
}

# 检查并安装依赖
install_dependencies() {
    log "检查系统依赖包..."
    
    # 更新包列表
    if ! pkg update -y; then
        error_log "包列表更新失败"
        return 1
    fi
    
    local required_packages=("php" "curl" "wget" "git")
    local missing_packages=()
    
    # 检查哪些包未安装
    for pkg in "${required_packages[@]}"; do
        if ! pkg list-installed | grep -q "$pkg"; then
            missing_packages+=("$pkg")
        fi
    done
    
    # 安装缺失的包
    if [ ${#missing_packages[@]} -gt 0 ]; then
        log "安装缺失的包: ${missing_packages[*]}"
        if ! pkg install -y "${missing_packages[@]}"; then
            error_log "包安装失败"
            return 1
        fi
    fi
    
    log "所有依赖包安装完成"
    return 0
}

# 获取存储权限
setup_storage() {
    log "设置存储权限..."
    
    # 运行termux存储设置
    if ! termux-setup-storage; then
        warning_log "存储设置命令执行失败，尝试继续..."
    fi
    
    # 等待用户授权
    log "请在弹出的对话框中授权存储权限..."
    sleep 5
    
    # 检查是否成功获取权限
    if [ -d "/storage/emulated/0" ]; then
        log "存储权限获取成功"
        return 0
    else
        error_log "存储权限获取失败，部分功能可能受限"
        return 1
    fi
}

# 创建目录结构
create_directories() {
    local base_dir="/storage/emulated/0/tvbox"
    local dirs=("php" "logs" "backups" "www" "data")
    
    log "创建目录结构..."
    
    for dir in "${dirs[@]}"; do
        local full_path="$base_dir/$dir"
        if mkdir -p "$full_path"; then
            log "创建目录: $full_path"
        else
            error_log "创建目录失败: $full_path"
            return 1
        fi
    done
    
    log "目录结构创建完成"
    return 0
}

# 创建配置文件
create_config_files() {
    local base_dir="/storage/emulated/0/tvbox"
    
    log "创建配置文件..."
    
    # 创建PHP配置文件
    cat > "$base_dir/data/server.conf" << EOF
# PHP服务器配置
SERVER_IP=0.0.0.0
SERVER_PORT=8081
DOCUMENT_ROOT=/storage/emulated/0/tvbox/php
LOG_FILE=/storage/emulated/0/tvbox/logs/php_server.log
AUTOSTART=true
VERSION=3.0
EOF

    # 创建默认PHP首页
    cat > "$base_dir/php/index.php" << 'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Termux PHP服务器</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .container {
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(15px);
            border-radius: 20px;
            padding: 40px;
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1);
            border: 1px solid rgba(255, 255, 255, 0.2);
            max-width: 800px;
            width: 100%;
            text-align: center;
        }
        .logo {
            font-size: 3em;
            margin-bottom: 20px;
        }
        h1 {
            color: #fff;
            margin-bottom: 30px;
            font-size: 2.5em;
            text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.3);
        }
        .status-card {
            background: rgba(255, 255, 255, 0.15);
            border-radius: 15px;
            padding: 25px;
            margin: 20px 0;
            text-align: left;
        }
        .status-item {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 12px 0;
            border-bottom: 1px solid rgba(255, 255, 255, 0.1);
        }
        .status-item:last-child {
            border-bottom: none;
        }
        .label {
            color: #e0e0e0;
            font-weight: 500;
        }
        .value {
            color: #4caf50;
            font-weight: bold;
        }
        .info-box {
            background: rgba(255, 235, 59, 0.2);
            border-left: 4px solid #ffeb3b;
            padding: 15px;
            margin: 20px 0;
            border-radius: 8px;
            text-align: left;
        }
        .server-info {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin: 25px 0;
        }
        .info-card {
            background: rgba(255, 255, 255, 0.1);
            padding: 15px;
            border-radius: 10px;
            text-align: center;
        }
        .info-card .icon {
            font-size: 2em;
            margin-bottom: 10px;
        }
        .btn {
            background: linear-gradient(45deg, #4caf50, #45a049);
            color: white;
            border: none;
            padding: 12px 30px;
            border-radius: 25px;
            font-size: 1.1em;
            cursor: pointer;
            margin: 10px;
            transition: all 0.3s ease;
            text-decoration: none;
            display: inline-block;
        }
        .btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 10px 20px rgba(0, 0, 0, 0.2);
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">🚀</div>
        <h1>PHP服务器运行成功！</h1>
        
        <div class="status-card">
            <div class="status-item">
                <span class="label">🟢 服务器状态</span>
                <span class="value">运行中</span>
            </div>
            <div class="status-item">
                <span class="label">📁 根目录</span>
                <span class="value">/storage/emulated/0/tvbox/php</span>
            </div>
            <div class="status-item">
                <span class="label">🌐 访问地址</span>
                <span class="value">
                    <?php
                    $ip = shell_exec("ip route get 1.2.3.4 2>/dev/null | awk '{print $7}' | head -1");
                    if(empty($ip)) $ip = '127.0.0.1';
                    echo 'http://'.trim($ip).':8081';
                    ?>
                </span>
            </div>
            <div class="status-item">
                <span class="label">🕐 启动时间</span>
                <span class="value"><?php echo date('Y-m-d H:i:s'); ?></span>
            </div>
        </div>

        <div class="server-info">
            <div class="info-card">
                <div class="icon">📊</div>
                <div>PHP版本: <?php echo PHP_VERSION; ?></div>
            </div>
            <div class="info-card">
                <div class="icon">💾</div>
                <div>内存使用: <?php echo round(memory_get_usage(true)/1048576, 2); ?> MB</div>
            </div>
            <div class="info-card">
                <div class="icon">⚡</div>
                <div>运行模式: <?php echo PHP_SAPI; ?></div>
            </div>
        </div>

        <div class="info-box">
            <strong>💡 使用提示：</strong>
            <p>将您的PHP文件放在 <code>/storage/emulated/0/tvbox/php</code> 目录即可通过浏览器访问。</p>
        </div>

        <a href="#" class="btn" onclick="location.reload()">🔄 刷新状态</a>
        <a href="/phpinfo.php" class="btn">🔧 PHP信息</a>
    </div>
</body>
</html>
EOF

    # 创建phpinfo文件
    cat > "$base_dir/php/phpinfo.php" << 'EOF'
<?php
// 简单的phpinfo页面，避免信息泄露
if (isset($_GET['info']) && $_GET['info'] === 'full') {
    phpinfo();
} else {
    echo '<!DOCTYPE html><html><head><title>PHP信息</title></head><body>';
    echo '<h1>PHP信息页面</h1>';
    echo '<p><a href="?info=full">查看完整PHP信息</a> | <a href="/">返回首页</a></p>';
    echo '<p>注意：完整PHP信息可能包含敏感数据，请谨慎分享。</p>';
    echo '</body></html>';
}
?>
EOF

    log "配置文件创建完成"
}

# 获取本机IP
get_ip_address() {
    local ip=$(ip route get 1.2.3.4 2>/dev/null | awk '{print $7}' | head -1)
    if [ -z "$ip" ]; then
        ip="127.0.0.1"
    fi
    echo $ip
}

# 启动PHP服务器
start_php_server() {
    log "启动PHP服务器..."
    
    local base_dir="/storage/emulated/0/tvbox"
    local php_dir="$base_dir/php"
    local log_file="$base_dir/logs/php_server.log"
    local ip=$(get_ip_address)
    
    # 停止已运行的PHP服务
    stop_php_server
    
    # 切换到PHP目录启动服务
    cd "$php_dir"
    
    # 启动PHP内置服务器
    nohup php -S "${ip}:8081" > "$log_file" 2>&1 &
    
    local server_pid=$!
    sleep 3
    
    # 检查服务是否启动成功
    if ps -p $server_pid > /dev/null 2>&1; then
        echo $server_pid > "$base_dir/data/php_server.pid"
        log "PHP服务器启动成功!"
        log "📱 本地访问: http://127.0.0.1:8081"
        log "🌐 网络访问: http://${ip}:8081"
        log "📁 网站根目录: $php_dir"
        log "📊 日志文件: $log_file"
        return 0
    else
        error_log "PHP服务器启动失败"
        return 1
    fi
}

# 停止PHP服务器
stop_php_server() {
    if [ -f "/storage/emulated/0/tvbox/data/php_server.pid" ]; then
        local pid=$(cat "/storage/emulated/0/tvbox/data/php_server.pid")
        if kill -0 $pid 2>/dev/null; then
            kill $pid
            log "停止PHP服务器 (PID: $pid)"
        fi
        rm -f "/storage/emulated/0/tvbox/data/php_server.pid"
    fi
    
    # 确保所有PHP服务器进程都被停止
    pkill -f "php -S" 2>/dev/null && log "清理残留PHP进程"
    sleep 2
}

# 设置开机自启动
setup_autostart() {
    log "设置开机自启动..."
    
    local autostart_file="$PREFIX/etc/bash.bashrc"
    local marker="# TERMUX_PHP_SERVER_AUTOSTART"
    
    # 移除旧的自动启动配置
    sed -i "/$marker/,/^fi $marker/d" "$autostart_file" 2>/dev/null
    
    # 添加新的自动启动配置
    cat >> "$autostart_file" << EOF

$marker
# Termux PHP服务器自动启动
if [ -z "\$PHP_SERVER_AUTOSTART" ] && [ ! -f /tmp/php_server_autostart.lock ]; then
    export PHP_SERVER_AUTOSTART=1
    echo -e "\\\\033[1;36m正在启动PHP服务器...\\\\033[0m"
    sleep 2
    cd /storage/emulated/0/tvbox/php && nohup php -S \$(ip route get 1.2.3.4 2>/dev/null | awk '{print \$7}' | head -1):8081 > /storage/emulated/0/tvbox/logs/autostart.log 2>&1 &
    touch /tmp/php_server_autostart.lock
    echo -e "\\\\033[1;32m✅ PHP服务器已自动启动\\\\033[0m"
    echo -e "\\\\033[1;36m访问地址: http://\$(ip route get 1.2.3.4 2>/dev/null | awk '{print \$7}' | head -1):8081\\\\033[0m"
fi $marker
EOF

    log "开机自启动设置完成"
}

# 创建管理脚本
create_management_script() {
    local script_path="$PREFIX/bin/php-server"
    
    log "创建管理脚本..."
    
    cat > "$script_path" << 'EOF'
#!/bin/bash

case "$1" in
    "start")
        cd /storage/emulated/0/tvbox/php
        ip=$(ip route get 1.2.3.4 2>/dev/null | awk '{print $7}' | head -1)
        nohup php -S ${ip}:8081 > /storage/emulated/0/tvbox/logs/php_server.log 2>&1 &
        echo $! > /storage/emulated/0/tvbox/data/php_server.pid
        echo "✅ PHP服务器已启动: http://${ip}:8081"
        ;;
    "stop")
        if [ -f "/storage/emulated/0/tvbox/data/php_server.pid" ]; then
            pid=$(cat "/storage/emulated/0/tvbox/data/php_server.pid")
            kill $pid
            rm -f "/storage/emulated/0/tvbox/data/php_server.pid"
            echo "✅ PHP服务器已停止"
        else
            pkill -f "php -S"
            echo "✅ 所有PHP服务器进程已停止"
        fi
        ;;
    "status")
        if pgrep -f "php -S" > /dev/null; then
            ip=$(ip route get 1.2.3.4 2>/dev/null | awk '{print $7}' | head -1)
            echo "✅ PHP服务器运行中"
            echo "🌐 访问地址: http://${ip}:8081"
        else
            echo "❌ PHP服务器未运行"
        fi
        ;;
    "restart")
        $0 stop
        sleep 2
        $0 start
        ;;
    "logs")
        tail -f /storage/emulated/0/tvbox/logs/php_server.log
        ;;
    *)
        echo "使用方法: php-server {start|stop|restart|status|logs}"
        ;;
esac
EOF

    chmod +x "$script_path"
    log "管理脚本创建完成: $script_path"
    log "使用命令: php-server start|stop|restart|status|logs"
}

# 显示安装完成信息
show_completion_info() {
    local ip=$(get_ip_address)
    
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║              🎉 安装完成！                  ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${CYAN}📱 服务器信息:${NC}"
    echo -e "${YELLOW}   本地访问: ${WHITE}http://127.0.0.1:8081${NC}"
    echo -e "${YELLOW}   网络访问: ${WHITE}http://${ip}:8081${NC}"
    echo -e "${YELLOW}   网站目录: ${WHITE}/storage/emulated/0/tvbox/php${NC}"
    echo -e ""
    echo -e "${CYAN}⚡ 管理命令:${NC}"
    echo -e "${YELLOW}   启动服务: ${WHITE}php-server start${NC}"
    echo -e "${YELLOW}   停止服务: ${WHITE}php-server stop${NC}"
    echo -e "${YELLOW}   服务状态: ${WHITE}php-server status${NC}"
    echo -e "${YELLOW}   查看日志: ${WHITE}php-server logs${NC}"
    echo -e ""
    echo -e "${CYAN}🔧 开机自启动:${NC}"
    echo -e "${GREEN}   ✅ 已启用 - 下次启动Termux将自动运行PHP服务器${NC}"
    echo -e ""
    echo -e "${PURPLE}💡 提示: 将您的PHP文件放入网站目录即可访问${NC}"
}

# 主安装函数
main_installation() {
    show_banner
    
    log "开始安装Termux PHP服务器..."
    
    # 执行安装步骤
    local steps=(
        "install_dependencies:安装系统依赖"
        "setup_storage:获取存储权限" 
        "create_directories:创建目录结构"
        "create_config_files:创建配置文件"
        "start_php_server:启动PHP服务器"
        "setup_autostart:设置开机自启动"
        "create_management_script:创建管理脚本"
    )
    
    for step in "${steps[@]}"; do
        local func="${step%:*}"
        local desc="${step#*:}"
        
        log "正在执行: $desc"
        if ! $func; then
            error_log "$desc 失败"
            echo -e "${RED}安装过程中遇到错误，安装终止。${NC}"
            exit 1
        fi
    done
    
    # 显示完成信息
    show_completion_info
}

# 检查是否直接运行脚本
if [ "$0" = "$BASH_SOURCE" ]; then
    main_installation
fi
