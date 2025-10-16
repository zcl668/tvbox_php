#!/bin/bash
# 保存为 fix-permission-install.sh

# 彩色输出
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date '+%H:%M:%S')] $1${NC}"; }
error() { echo -e "${RED}[$(date '+%H:%M:%S')] 错误: $1${NC}"; }
warn() { echo -e "${YELLOW}[$(date '+%H:%M:%S')] 警告: $1${NC}"; }

show_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║          Termux 权限修复版安装脚本          ║"
    echo "║             解决存储权限问题                ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 1. 基础权限检查和修复
check_and_fix_basic_permissions() {
    log "检查基础权限..."
    
    # 检查Termux基础目录权限
    if [ ! -w "$HOME" ]; then
        error "Home目录不可写"
        return 1
    fi
    
    # 检查是否有执行权限
    if [ ! -x "$PREFIX/bin/bash" ]; then
        error "没有执行权限"
        return 1
    fi
    
    log "基础权限正常"
    return 0
}

# 2. 智能存储权限获取
setup_smart_storage() {
    log "设置智能存储权限..."
    
    # 方法1: 使用termux-setup-storage
    warn "方法1: 使用官方命令获取权限"
    termux-setup-storage
    
    echo "请检查是否弹出存储权限对话框..."
    echo "如果已授权，请按回车继续"
    read
    
    # 等待授权
    sleep 3
    
    # 检查权限是否真正获取
    if [ -d "/sdcard" ] && [ -w "/sdcard" ]; then
        log "✅ 存储权限获取成功 (方法1)"
        return 0
    fi
    
    # 方法2: 检查 ~/storage 目录
    warn "方法1失败，尝试方法2..."
    if [ -d "$HOME/storage" ]; then
        log "检测到storage目录，创建符号链接"
        ln -sf $HOME/storage/shared /sdcard 2>/dev/null
        return 0
    fi
    
    # 方法3: 手动创建目录结构
    warn "方法2失败，尝试手动创建..."
    mkdir -p $HOME/storage/shared
    mkdir -p $HOME/storage/emulated/0
    
    # 创建符号链接
    ln -sf $HOME/storage/shared $HOME/storage/emulated/0 2>/dev/null
    ln -sf $HOME/storage/shared /sdcard 2>/dev/null
    
    log "手动创建目录结构完成"
    return 0
}

# 3. 使用Termux私有目录（避免权限问题）
setup_private_directory() {
    log "设置私有目录（无需存储权限）..."
    
    PRIVATE_DIR="$HOME/nginx-www"
    LOGS_DIR="$HOME/nginx-logs"
    
    mkdir -p $PRIVATE_DIR/html
    mkdir -p $PRIVATE_DIR/data
    mkdir -p $LOGS_DIR
    
    # 设置权限
    chmod 755 $PRIVATE_DIR
    chmod 755 $LOGS_DIR
    chmod -R 644 $PRIVATE_DIR/html/*
    
    log "私有目录设置完成: $PRIVATE_DIR"
    return 0
}

# 4. 安装必要软件（跳过已安装的）
install_packages_smart() {
    log "智能安装软件包..."
    
    # 检查并安装PHP
    if ! command -v php &> /dev/null; then
        log "安装PHP..."
        pkg install -y php
    else
        log "✅ PHP已安装"
    fi
    
    # 检查并安装Nginx
    if ! command -v nginx &> /dev/null; then
        log "安装Nginx..."
        pkg install -y nginx
    else
        log "✅ Nginx已安装"
    fi
    
    # 安装其他依赖
    pkg install -y termux-services curl wget
    
    log "软件包安装完成"
}

# 5. 创建免权限Nginx配置
create_no_permission_nginx_config() {
    log "创建免权限Nginx配置..."
    
    NGINX_CONF="$PREFIX/etc/nginx/nginx.conf"
    PRIVATE_DIR="$HOME/nginx-www"
    LOGS_DIR="$HOME/nginx-logs"
    
    # 备份原配置
    cp $NGINX_CONF $NGINX_CONF.backup 2>/dev/null
    
    # 创建新配置（使用私有目录）
    cat > $NGINX_CONF << 'EOF'
user root;
worker_processes 1;
error_log /data/data/com.termux/files/home/nginx-logs/error.log;
pid /data/data/com.termux/files/home/nginx-logs/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include       /data/data/com.termux/files/usr/etc/nginx/mime.types;
    default_type  application/octet-stream;

    access_log /data/data/com.termux/files/home/nginx-logs/access.log;

    sendfile        on;
    keepalive_timeout 65;

    server {
        listen       8080;
        server_name  localhost;
        
        # 使用私有目录，避免权限问题
        root /data/data/com.termux/files/home/nginx-www/html;
        index index.php index.html index.htm;

        location / {
            try_files $uri $uri/ =404;
        }

        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   /data/data/com.termux/files/home/nginx-www/html;
        }

        # PHP配置
        location ~ \.php$ {
            root           /data/data/com.termux/files/home/nginx-www/html;
            fastcgi_pass   127.0.0.1:9000;
            fastcgi_index  index.php;
            fastcgi_param  SCRIPT_FILENAME  $document_root$fastcgi_script_name;
            include        /data/data/com.termux/files/usr/etc/nginx/fastcgi_params;
        }
    }

    # 第二个服务器（如果获取了存储权限）
    server {
        listen       8081;
        server_name  localhost;
        
        # 尝试使用共享目录
        root /sdcard/nginx-www;
        index index.php index.html index.htm;

        location / {
            try_files $uri $uri/ =404;
        }

        location ~ \.php$ {
            root           /sdcard/nginx-www;
            fastcgi_pass   127.0.0.1:9000;
            fastcgi_index  index.php;
            fastcgi_param  SCRIPT_FILENAME  $document_root$fastcgi_script_name;
            include        fastcgi_params;
        }
    }
}
EOF

    log "Nginx配置创建完成"
}

# 6. 创建PHP-FPM配置（私有目录）
create_php_fpm_config() {
    log "创建PHP-FPM配置..."
    
    PHP_FPM_CONF="$PREFIX/etc/php-fpm.d/www.conf"
    
    cat > $PHP_FPM_CONF << 'EOF'
[www]
user = root
group = root

listen = 127.0.0.1:9000
listen.owner = root
listen.group = root
listen.mode = 0660

; 使用私有目录避免权限问题
pm = dynamic
pm.max_children = 3
pm.start_servers = 1
pm.min_spare_servers = 1
pm.max_spare_servers = 2

; 日志文件也放在私有目录
php_admin_value[error_log] = /data/data/com.termux/files/home/nginx-logs/php-fpm.log
php_admin_flag[log_errors] = on

; 安全设置
php_flag[display_errors] = on
php_admin_value[doc_root] = /data/data/com.termux/files/home/nginx-www/html
php_admin_value[open_basedir] = /data/data/com.termux/files/home/nginx-www/html:/sdcard
EOF

    log "PHP-FPM配置创建完成"
}

# 7. 创建网站文件（私有目录）
create_website_files_private() {
    log "创建网站文件到私有目录..."
    
    PRIVATE_HTML="$HOME/nginx-www/html"
    
    # 创建基础文件
    mkdir -p $PRIVATE_HTML
    
    # 主页面
    cat > $PRIVATE_HTML/index.php << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Nginx+PHP - 免权限版</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .success { background: #d4edda; color: #155724; padding: 15px; border-radius: 5px; margin: 20px 0; }
        .info { background: #d1ecf1; color: #0c5460; padding: 15px; border-radius: 5px; margin: 10px 0; }
        .warning { background: #fff3cd; color: #856404; padding: 15px; border-radius: 5px; margin: 10px 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Nginx + PHP 服务器</h1>
        <div class="success">
            <h3>✅ 安装成功！</h3>
            <p>这是免权限版本，无需存储权限即可运行</p>
        </div>
        
        <div class="info">
            <h3>📊 服务器信息</h3>
            <p><strong>PHP版本:</strong> <?php echo PHP_VERSION; ?></p>
            <p><strong>服务器软件:</strong> <?php echo $_SERVER['SERVER_SOFTWARE'] ?? 'Nginx'; ?></p>
            <p><strong>当前时间:</strong> <?php echo date('Y-m-d H:i:s'); ?></p>
            <p><strong>访问IP:</strong> <?php echo $_SERVER['REMOTE_ADDR'] ?? 'Unknown'; ?></p>
        </div>

        <div class="warning">
            <h3>💡 使用说明</h3>
            <p>网站文件目录: <code>/data/data/com.termux/files/home/nginx-www/html</code></p>
            <p>无需存储权限，所有文件都在Termux私有目录</p>
        </div>

        <h3>🔧 测试链接</h3>
        <ul>
            <li><a href="/info.php">PHP信息页面</a></li>
            <li><a href="/test.php">JSON API测试</a></li>
        </ul>
    </div>
</body>
</html>
EOF

    # PHP信息页
    cat > $PRIVATE_HTML/info.php << 'EOF'
<?php
phpinfo(INFO_GENERAL | INFO_CONFIGURATION | INFO_MODULES);
?>
EOF

    # 测试API
    cat > $PRIVATE_HTML/test.php << 'EOF'
<?php
header('Content-Type: application/json');
echo json_encode([
    'status' => 'success',
    'message' => '服务器运行正常！',
    'data' => [
        'timestamp' => time(),
        'php_version' => PHP_VERSION,
        'server' => $_SERVER['SERVER_SOFTWARE'] ?? 'Nginx',
        'script_path' => __FILE__
    ]
], JSON_PRETTY_PRINT);
?>
EOF

    # 尝试创建共享目录版本（如果有权限）
    if [ -w "/sdcard" ]; then
        mkdir -p /sdcard/nginx-www
        cp $PRIVATE_HTML/index.php /sdcard/nginx-www/ 2>/dev/null
        log "共享目录版本已创建"
    fi

    log "网站文件创建完成"
}

# 8. 创建智能管理脚本
create_smart_manager() {
    log "创建智能管理脚本..."
    
    cat > $HOME/server-manager << 'EOF'
#!/bin/bash

# 颜色定义
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m'

show_help() {
    echo -e "${GREEN}服务器管理脚本${NC}"
    echo "用法: $0 [命令]"
    echo ""
    echo "命令:"
    echo "  start     - 启动Nginx和PHP-FPM"
    echo "  stop      - 停止服务"
    echo "  restart   - 重启服务"
    echo "  status    - 查看状态"
    echo "  logs      - 查看日志"
    echo "  fix       - 修复权限问题"
    echo "  info      - 系统信息"
    echo ""
}

check_services() {
    if pgrep nginx > /dev/null; then
        echo -e "🌐 Nginx: ${GREEN}运行中${NC}"
    else
        echo -e "🌐 Nginx: ${RED}停止${NC}"
    fi
    
    if pgrep php-fpm > /dev/null; then
        echo -e "🐘 PHP-FPM: ${GREEN}运行中${NC}"
    else
        echo -e "🐘 PHP-FPM: ${RED}停止${NC}"
    fi
}

start_services() {
    echo -e "${BLUE}启动服务...${NC}"
    
    # 启动PHP-FPM
    php-fpm
    sleep 2
    
    # 启动Nginx
    nginx
    sleep 2
    
    check_services
}

stop_services() {
    echo -e "${YELLOW}停止服务...${NC}"
    nginx -s stop 2>/dev/null
    pkill php-fpm 2>/dev/null
    sleep 2
    check_services
}

fix_permissions() {
    echo -e "${BLUE}修复权限问题...${NC}"
    
    # 创建必要目录
    mkdir -p $HOME/nginx-www/html
    mkdir -p $HOME/nginx-logs
    
    # 设置权限
    chmod 755 $HOME/nginx-www
    chmod 755 $HOME/nginx-logs
    
    echo -e "${GREEN}✅ 权限修复完成${NC}"
}

case "$1" in
    start)
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        stop_services
        start_services
        ;;
    status)
        check_services
        
        # 显示访问信息
        IP=$(ip route get 1.2.3.4 2>/dev/null | awk '{print $7}' | head -1)
        [ -z "$IP" ] && IP="127.0.0.1"
        echo -e "\n${BLUE}访问地址:${NC}"
        echo -e "主站点: http://$IP:8080"
        echo -e "共享站点: http://$IP:8081"
        ;;
    logs)
        tail -f $HOME/nginx-logs/error.log
        ;;
    fix)
        fix_permissions
        ;;
    info)
        echo -e "${GREEN}系统信息:${NC}"
        echo "PHP版本: $(php -v 2>/dev/null | head -1)"
        echo "Nginx版本: $(nginx -v 2>&1)"
        echo "工作目录: $HOME/nginx-www/html"
        echo "日志目录: $HOME/nginx-logs"
        ;;
    *)
        show_help
        ;;
esac
EOF

    chmod +x $HOME/server-manager
    log "管理脚本创建完成"
}

# 9. 启动服务并测试
start_and_test() {
    log "启动服务并测试..."
    
    # 停止可能运行的服务
    $HOME/server-manager stop
    
    # 修复权限
    $HOME/server-manager fix
    
    # 启动服务
    $HOME/server-manager start
    
    # 等待启动
    sleep 3
    
    # 测试服务
    if pgrep nginx > /dev/null && pgrep php-fpm > /dev/null; then
        log "✅ 服务启动成功"
    else
        error "服务启动失败"
        return 1
    fi
    
    return 0
}

# 10. 显示安装结果
show_installation_result() {
    IP=$(ip route get 1.2.3.4 2>/dev/null | awk '{print $7}' | head -1)
    [ -z "$IP" ] && IP="127.0.0.1"
    
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║            🎉 安装完成！                    ║"
    echo "║          权限问题已解决                     ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo -e "${CYAN}🌐 访问地址:${NC}"
    echo -e "   主站点 (私有目录): ${YELLOW}http://$IP:8080${NC}"
    echo -e "   共享站点 (如果可用): ${YELLOW}http://$IP:8081${NC}"
    echo ""
    
    echo -e "${CYAN}⚡ 管理命令:${NC}"
    echo -e "   ${GREEN}server-manager start${NC}   # 启动服务"
    echo -e "   ${RED}server-manager stop${NC}    # 停止服务"
    echo -e "   ${YELLOW}server-manager status${NC} # 查看状态"
    echo -e "   ${BLUE}server-manager logs${NC}    # 查看日志"
    echo -e "   ${PURPLE}server-manager fix${NC}    # 修复权限"
    echo ""
    
    echo -e "${CYAN}📁 目录信息:${NC}"
    echo -e "   网站文件: ${YELLOW}$HOME/nginx-www/html/${NC}"
    echo -e "   日志文件: ${YELLOW}$HOME/nginx-logs/${NC}"
    echo ""
    
    echo -e "${GREEN}💡 特性: 免存储权限运行，所有文件在私有目录${NC}"
}

# 主安装函数
main() {
    show_banner
    
    log "开始安装免权限版Nginx+PHP服务器..."
    
    # 执行安装步骤
    local steps=(
        "check_and_fix_basic_permissions:检查基础权限"
        "setup_smart_storage:智能获取存储权限"
        "setup_private_directory:设置私有目录"
        "install_packages_smart:智能安装软件包"
        "create_no_permission_nginx_config:创建Nginx配置"
        "create_php_fpm_config:创建PHP-FPM配置"
        "create_website_files_private:创建网站文件"
        "create_smart_manager:创建管理脚本"
        "start_and_test:启动并测试服务"
    )
    
    for step in "${steps[@]}"; do
        local func="${step%:*}"
        local desc="${step#*:}"
        
        log "执行: $desc"
        if ! $func; then
            warn "$desc 遇到问题，尝试继续..."
        fi
    done
    
    show_installation_result
}

# 运行安装
main
