#!/bin/bash
# 保存为 install-nginx-php.sh

# 彩色输出
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m'

show_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║           Nginx + PHP 服务器栈              ║"
    echo "║             一键安装配置工具                ║"
    echo "║                支持后台运行                 ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] $1${NC}"
}

error_log() {
    echo -e "${RED}[$(date '+%H:%M:%S')] 错误: $1${NC}"
}

warning_log() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] 警告: $1${NC}"
}

# 安装依赖包
install_dependencies() {
    log "安装必要软件包..."
    
    pkg update -y
    pkg install -y nginx php php-fpm curl wget git termux-services
    
    if [ $? -ne 0 ]; then
        error_log "软件包安装失败"
        return 1
    fi
    
    log "软件包安装完成"
    return 0
}

# 设置存储权限
setup_storage() {
    log "设置存储权限..."
    termux-setup-storage
    echo "请授权存储权限..."
    sleep 5
}

# 创建目录结构
create_directories() {
    log "创建目录结构..."
    
    local base_dir="/data/data/com.termux/files/usr/var/www"
    local shared_dir="/storage/emulated/0/nginx-www"
    
    # Nginx标准目录
    mkdir -p $base_dir/html
    mkdir -p $base_dir/logs
    mkdir -p $base_dir/ssl
    mkdir -p ~/nginx-conf
    
    # 共享目录（用于存放网站文件）
    mkdir -p $shared_dir/html
    mkdir -p $shared_dir/logs
    mkdir -p $shared_dir/backups
    
    log "目录结构创建完成"
}

# 配置Nginx
configure_nginx() {
    log "配置Nginx..."
    
    local nginx_prefix="/data/data/com.termux/files/usr"
    local conf_dir="$nginx_prefix/etc/nginx"
    local www_dir="/data/data/com.termux/files/usr/var/www"
    
    # 备份原始配置
    cp $conf_dir/nginx.conf $conf_dir/nginx.conf.backup 2>/dev/null
    
    # 创建优化的Nginx配置
    cat > $conf_dir/nginx.conf << 'EOF'
user root;
worker_processes 1;
pid /data/data/com.termux/files/usr/var/run/nginx.pid;

events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    include       /data/data/com.termux/files/usr/etc/nginx/mime.types;
    default_type  application/octet-stream;

    # 日志格式
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /data/data/com.termux/files/usr/var/www/logs/access.log main;
    error_log /data/data/com.termux/files/usr/var/www/logs/error.log warn;

    # 基本设置
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 100M;

    # Gzip压缩
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    # 虚拟主机配置
    server {
        listen 8080 reuseport;
        listen [::]:8080 reuseport;
        server_name localhost;
        
        root /data/data/com.termux/files/usr/var/www/html;
        index index.php index.html index.htm;

        # 安全头
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header X-Content-Type-Options "nosniff" always;

        # PHP处理
        location ~ \.php$ {
            try_files $uri =404;
            fastcgi_split_path_info ^(.+\.php)(/.+)$;
            fastcgi_pass 127.0.0.1:9000;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            include /data/data/com.termux/files/usr/etc/nginx/fastcgi.conf;
        }

        # 静态文件缓存
        location ~* \.(jpg|jpeg|png|gif|ico|css|js|pdf)$ {
            expires 7d;
            add_header Cache-Control "public, immutable";
        }

        # 禁止访问隐藏文件
        location ~ /\. {
            deny all;
            access_log off;
            log_not_found off;
        }

        # 错误页面
        error_page 404 /404.html;
        error_page 500 502 503 504 /50x.html;
    }

    # 第二个虚拟主机（可选，用于测试）
    server {
        listen 8081;
        server_name test.localhost;
        root /storage/emulated/0/nginx-www/html;
        index index.php index.html;

        location / {
            try_files $uri $uri/ =404;
        }

        location ~ \.php$ {
            fastcgi_pass 127.0.0.1:9000;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            include fastcgi_params;
        }
    }
}
EOF

    # 创建FastCGI配置
    cat > $conf_dir/fastcgi.conf << 'EOF'
fastcgi_param  SCRIPT_FILENAME    $document_root$fastcgi_script_name;
fastcgi_param  QUERY_STRING       $query_string;
fastcgi_param  REQUEST_METHOD     $request_method;
fastcgi_param  CONTENT_TYPE       $content_type;
fastcgi_param  CONTENT_LENGTH     $content_length;

fastcgi_param  SCRIPT_NAME        $fastcgi_script_name;
fastcgi_param  REQUEST_URI        $request_uri;
fastcgi_param  DOCUMENT_URI       $document_uri;
fastcgi_param  DOCUMENT_ROOT      $document_root;
fastcgi_param  SERVER_PROTOCOL    $server_protocol;
fastcgi_param  REQUEST_SCHEME     $scheme;
fastcgi_param  HTTPS              $https if_not_empty;

fastcgi_param  GATEWAY_INTERFACE  CGI/1.1;
fastcgi_param  SERVER_SOFTWARE    nginx/$nginx_version;

fastcgi_param  REMOTE_ADDR        $remote_addr;
fastcgi_param  REMOTE_PORT        $remote_port;
fastcgi_param  SERVER_ADDR        $server_addr;
fastcgi_param  SERVER_PORT        $server_port;
fastcgi_param  SERVER_NAME        $server_name;

# PHP only, required if PHP was built with --enable-force-cgi-redirect
fastcgi_param  REDIRECT_STATUS    200;
EOF

    log "Nginx配置完成"
}

# 配置PHP-FPM
configure_php_fpm() {
    log "配置PHP-FPM..."
    
    local php_conf_dir="/data/data/com.termux/files/usr/etc"
    
    # 创建PHP-FPM配置
    cat > $php_conf_dir/php-fpm.d/www.conf << 'EOF'
[www]
user = root
group = root

listen = 127.0.0.1:9000
listen.owner = root
listen.group = root
listen.mode = 0660

pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3

pm.max_requests = 500

slowlog = /data/data/com.termux/files/usr/var/www/logs/php_slow.log
request_slowlog_timeout = 5s

php_admin_value[error_log] = /data/data/com.termux/files/usr/var/www/logs/php_error.log
php_admin_flag[log_errors] = on

; 安全设置
php_flag[display_errors] = off
php_admin_value[doc_root] = /data/data/com.termux/files/usr/var/www/html
php_admin_value[open_basedir] = /data/data/com.termux/files/usr/var/www/html:/storage/emulated/0/nginx-www
EOF

    # 创建PHP配置文件
    cat > $php_conf_dir/php.ini << 'EOF'
[PHP]
engine = On
short_open_tag = Off
precision = 14
output_buffering = 4096
zlib.output_compression = Off
implicit_flush = Off
unserialize_callback_func =
serialize_precision = -1

; 错误处理
display_errors = Off
display_startup_errors = Off
log_errors = On
error_log = /data/data/com.termux/files/usr/var/www/logs/php_errors.log

; 文件上传
file_uploads = On
upload_max_filesize = 100M
max_file_uploads = 20

; 数据提交
post_max_size = 100M
max_input_time = 60
max_input_vars = 1000

; 内存限制
memory_limit = 256M

; 时区设置
date.timezone = Asia/Shanghai

; 会话配置
session.save_handler = files
session.save_path = "/data/data/com.termux/files/usr/tmp"
session.use_strict_mode = 1
session.cookie_httponly = 1

; 扩展启用
extension=curl
extension=gd
extension=mbstring
extension=mysqli
extension=openssl
extension=pdo_mysql
extension=sqlite3
extension=zip
EOF

    log "PHP-FPM配置完成"
}

# 创建网站文件
create_website_files() {
    log "创建网站文件..."
    
    local www_dir="/data/data/com.termux/files/usr/var/www/html"
    local shared_dir="/storage/emulated/0/nginx-www/html"
    
    # 主站点文件
    cat > $www_dir/index.php << 'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Nginx + PHP 服务器</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: 'Segoe UI', system-ui, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
            color: #333;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: rgba(255,255,255,0.95);
            border-radius: 20px;
            padding: 40px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.1);
            backdrop-filter: blur(10px);
        }
        .header {
            text-align: center;
            margin-bottom: 40px;
        }
        .header h1 {
            font-size: 2.5em;
            background: linear-gradient(45deg, #667eea, #764ba2);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            margin-bottom: 10px;
        }
        .status-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin: 30px 0;
        }
        .status-card {
            background: white;
            padding: 25px;
            border-radius: 15px;
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
            border-left: 5px solid #4CAF50;
        }
        .status-card.nginx { border-left-color: #269c3e; }
        .status-card.php { border-left-color: #777BB3; }
        .status-card.info { border-left-color: #2196F3; }
        .status-card h3 { margin-bottom: 15px; color: #333; }
        .status-item { 
            display: flex; 
            justify-content: space-between; 
            padding: 8px 0;
            border-bottom: 1px solid #f0f0f0;
        }
        .status-item:last-child { border-bottom: none; }
        .badge {
            padding: 4px 12px;
            border-radius: 20px;
            font-size: 0.8em;
            font-weight: bold;
        }
        .badge.success { background: #4CAF50; color: white; }
        .badge.running { background: #4CAF50; color: white; }
        .badge.stopped { background: #f44336; color: white; }
        .services-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin: 20px 0;
        }
        .service-item {
            text-align: center;
            padding: 20px;
            background: #f8f9fa;
            border-radius: 10px;
            transition: transform 0.3s ease;
        }
        .service-item:hover {
            transform: translateY(-5px);
            box-shadow: 0 10px 20px rgba(0,0,0,0.1);
        }
        .service-icon {
            font-size: 2.5em;
            margin-bottom: 10px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 Nginx + PHP 服务器</h1>
            <p>高性能Web服务器栈 - 运行在Termux</p>
        </div>

        <div class="status-grid">
            <div class="status-card nginx">
                <h3>🌐 Nginx 状态</h3>
                <div class="status-item">
                    <span>服务状态:</span>
                    <span class="badge running">运行中</span>
                </div>
                <div class="status-item">
                    <span>端口:</span>
                    <span>8080, 8081</span>
                </div>
                <div class="status-item">
                    <span>版本:</span>
                    <span><?php echo shell_exec('nginx -v 2>&1'); ?></span>
                </div>
            </div>

            <div class="status-card php">
                <h3>🐘 PHP-FPM 状态</h3>
                <div class="status-item">
                    <span>服务状态:</span>
                    <span class="badge running">运行中</span>
                </div>
                <div class="status-item">
                    <span>PHP版本:</span>
                    <span><?php echo PHP_VERSION; ?></span>
                </div>
                <div class="status-item">
                    <span>监听地址:</span>
                    <span>127.0.0.1:9000</span>
                </div>
            </div>

            <div class="status-card info">
                <h3>📊 服务器信息</h3>
                <div class="status-item">
                    <span>服务器IP:</span>
                    <span><?php 
                        $ip = shell_exec("ip route get 1.2.3.4 2>/dev/null | awk '{print \$7}' | head -1");
                        if(empty($ip)) $ip = $_SERVER['SERVER_ADDR'] ?? '127.0.0.1';
                        echo trim($ip);
                    ?></span>
                </div>
                <div class="status-item">
                    <span>当前时间:</span>
                    <span><?php echo date('Y-m-d H:i:s'); ?></span>
                </div>
                <div class="status-item">
                    <span>运行模式:</span>
                    <span>Nginx + PHP-FPM</span>
                </div>
            </div>
        </div>

        <div class="services-grid">
            <div class="service-item">
                <div class="service-icon">📁</div>
                <h4>网站根目录</h4>
                <p>/usr/var/www/html</p>
            </div>
            <div class="service-item">
                <div class="service-icon">🔧</div>
                <h4>PHP信息</h4>
                <p><a href="/info.php">查看详情</a></p>
            </div>
            <div class="service-item">
                <div class="service-icon">📊</div>
                <h4>Nginx状态</h4>
                <p><a href="/status">状态页</a></p>
            </div>
            <div class="service-item">
                <div class="service-icon">⚡</div>
                <h4>性能模式</h4>
                <p>已优化配置</p>
            </div>
        </div>
    </div>
</body>
</html>
EOF

    # PHP信息页
    cat > $www_dir/info.php << 'EOF'
<?php
// 简化的phpinfo，避免信息泄露
if (isset($_GET['full']) && $_GET['full'] == '1') {
    phpinfo();
} else {
    echo '<!DOCTYPE html><html><head><title>PHP信息</title></head><body>';
    echo '<h1>PHP配置信息</h1>';
    echo '<p><a href="?full=1">查看完整PHP信息</a> | <a href="/">返回首页</a></p>';
    echo '<div style="background:#f8f9fa;padding:20px;border-radius:10px;">';
    echo '<h3>基本配置:</h3>';
    echo '<p><strong>PHP版本:</strong> ' . PHP_VERSION . '</p>';
    echo '<p><strong>运行模式:</strong> ' . PHP_SAPI . '</p>';
    echo '<p><strong>内存限制:</strong> ' . ini_get('memory_limit') . '</p>';
    echo '<p><strong>上传限制:</strong> ' . ini_get('upload_max_filesize') . '</p>';
    echo '<p><strong>时区:</strong> ' . date_default_timezone_get() . '</p>';
    echo '</div>';
    echo '</body></html>';
}
?>
EOF

    # 测试PHP文件
    cat > $www_dir/test.php << 'EOF'
<?php
header('Content-Type: application/json');
echo json_encode([
    'status' => 'success',
    'message' => 'PHP is working!',
    'data' => [
        'server_software' => $_SERVER['SERVER_SOFTWARE'] ?? 'Nginx',
        'php_version' => PHP_VERSION,
        'timestamp' => time(),
        'remote_addr' => $_SERVER['REMOTE_ADDR'] ?? 'unknown'
    ]
], JSON_PRETTY_PRINT);
?>
EOF

    # 共享目录也创建测试文件
    cat > $shared_dir/index.php << 'EOF'
<h1>共享目录网站</h1>
<p>这是存储在共享目录的网站文件</p>
<p>访问端口: 8081</p>
<p><a href="/">返回主站点</a></p>
EOF

    log "网站文件创建完成"
}

# 创建管理脚本
create_management_scripts() {
    log "创建管理脚本..."
    
    # 主管理脚本
    cat > ~/nginx-manager << 'EOF'
#!/bin/bash

case "$1" in
    "start")
        echo "启动Nginx + PHP服务..."
        nginx
        php-fpm
        echo "✅ 服务启动完成"
        ;;
    "stop")
        echo "停止Nginx + PHP服务..."
        nginx -s stop 2>/dev/null
        pkill php-fpm 2>/dev/null
        echo "✅ 服务已停止"
        ;;
    "restart")
        echo "重启服务..."
        nginx -s stop 2>/dev/null
        pkill php-fpm 2>/dev/null
        sleep 2
        nginx
        php-fpm
        echo "✅ 服务重启完成"
        ;;
    "status")
        echo "服务状态:"
        if pgrep nginx > /dev/null; then
            echo "🌐 Nginx: 运行中"
        else
            echo "🌐 Nginx: 停止"
        fi
        if pgrep php-fpm > /dev/null; then
            echo "🐘 PHP-FPM: 运行中"
        else
            echo "🐘 PHP-FPM: 停止"
        fi
        ;;
    "reload")
        nginx -s reload
        echo "✅ Nginx配置重载"
        ;;
    "logs")
        tail -f /data/data/com.termux/files/usr/var/www/logs/error.log
        ;;
    "config")
        vim /data/data/com.termux/files/usr/etc/nginx/nginx.conf
        ;;
    *)
        echo "使用方法: nginx-manager {start|stop|restart|status|reload|logs|config}"
        echo ""
        echo "📝 示例:"
        echo "  nginx-manager start    # 启动服务"
        echo "  nginx-manager stop     # 停止服务"
        echo "  nginx-manager status   # 查看状态"
        echo "  nginx-manager logs     # 查看日志"
        ;;
esac
EOF

    chmod +x ~/nginx-manager
    
    # 后台运行脚本
    cat > ~/.termux/boot/start-nginx-php << 'EOF'
#!/bin/bash
# Termux启动时自动运行Nginx+PHP

sleep 10

# 启动服务
nginx
php-fpm

# 记录启动日志
echo "[$(date)] Nginx+PHP 自动启动" >> /storage/emulated/0/nginx-www/logs/boot.log
EOF

    chmod +x ~/.termux/boot/start-nginx-php
    
    log "管理脚本创建完成"
}

# 启动服务
start_services() {
    log "启动Nginx和PHP-FPM服务..."
    
    # 停止可能运行的服务
    nginx -s stop 2>/dev/null
    pkill php-fpm 2>/dev/null
    sleep 2
    
    # 启动PHP-FPM
    php-fpm
    sleep 2
    
    # 启动Nginx
    nginx
    sleep 2
    
    # 检查服务状态
    if pgrep nginx > /dev/null && pgrep php-fpm > /dev/null; then
        log "✅ 所有服务启动成功"
    else
        error_log "服务启动失败，请检查日志"
        return 1
    fi
    
    return 0
}

# 显示安装结果
show_result() {
    local ip=$(ip route get 1.2.3.4 2>/dev/null | awk '{print $7}' | head -1)
    [ -z "$ip" ] && ip="127.0.0.1"
    
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║            🎉 安装完成！                    ║"
    echo "║        Nginx + PHP 服务器栈就绪            ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${CYAN}🌐 访问地址:${NC}"
    echo -e "   主站点: ${YELLOW}http://$ip:8080${NC}"
    echo -e "   测试站点: ${YELLOW}http://$ip:8081${NC}"
    echo -e "   PHP信息: ${YELLOW}http://$ip:8080/info.php${NC}"
    echo ""
    echo -e "${CYAN}⚡ 管理命令:${NC}"
    echo -e "   ${GREEN}nginx-manager start${NC}    # 启动服务"
    echo -e "   ${RED}nginx-manager stop${NC}     # 停止服务"  
    echo -e "   ${YELLOW}nginx-manager status${NC}  # 查看状态"
    echo -e "   ${BLUE}nginx-manager logs${NC}     # 查看日志"
    echo ""
    echo -e "${CYAN}📁 目录结构:${NC}"
    echo -e "   网站根目录: ${WHITE}/usr/var/www/html${NC}"
    echo -e "   共享目录: ${WHITE}/storage/emulated/0/nginx-www${NC}"
    echo -e "   日志目录: ${WHITE}/usr/var/www/logs${NC}"
    echo ""
    echo -e "${PURPLE}💡 特性: 支持后台运行，开机自启！${NC}"
}

# 主安装函数
main_installation() {
    show_banner
    
    local steps=(
        "install_dependencies:安装软件包"
        "setup_storage:设置存储权限"
        "create_directories:创建目录结构"
        "configure_nginx:配置Nginx"
        "configure_php_fpm:配置PHP-FPM"
        "create_website_files:创建网站文件"
        "create_management_scripts:创建管理脚本"
        "start_services:启动服务"
    )
    
    for step in "${steps[@]}"; do
        local func="${step%:*}"
        local desc="${step#*:}"
        
        log "执行: $desc"
        if ! $func; then
            error_log "$desc 失败"
            return 1
        fi
    done
    
    show_result
}

# 运行安装
main_installation
