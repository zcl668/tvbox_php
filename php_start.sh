#!/data/data/com.termux/files/usr/bin/bash
# --------------------------------------
# Termux PHP 远程一键安装脚本
# 作者：木凡
# GitHub: https://github.com/你的用户名
# --------------------------------------

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 输出彩色信息
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查并安装依赖
check_dependencies() {
    info "检查依赖..."
    
    if ! command -v curl &> /dev/null; then
        warning "未找到 curl，正在安装..."
        pkg install -y curl
    fi
    
    if ! command -v wget &> /dev/null; then
        warning "未找到 wget，正在安装..."
        pkg install -y wget
    fi
}

# 主安装函数
main_install() {
    info "🚀 开始安装 PHP 环境..."
    
    # 更新包管理器
    info "📦 更新软件包列表..."
    pkg update -y
    
    # 安装 PHP
    info "🔧 安装 PHP..."
    pkg install -y php
    
    # 申请存储访问权限
    info "📁 申请存储权限..."
    termux-setup-storage
    
    # 等待存储权限生效
    info "⏳ 等待存储权限生效..."
    sleep 5
    
    # 创建网站目录
    WEB_DIR="/storage/emulated/0/termux-php-server"
    info "📂 创建网站目录: $WEB_DIR"
    mkdir -p "$WEB_DIR"
    
    # 创建默认测试页面
    create_test_page
    
    # 配置自动启动
    setup_autostart
    
    # 启动服务
    start_service
    
    # 显示结果
    show_result
}

# 创建测试页面
create_test_page() {
    if [ ! -f "$WEB_DIR/index.php" ]; then
        info "📄 创建默认首页..."
        cat > "$WEB_DIR/index.php" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Termux PHP Server</title>
    <meta charset="utf-8">
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .success { color: green; }
        .info { background: #f0f8ff; padding: 15px; border-radius: 5px; }
    </style>
</head>
<body>
    <h1>🎉 PHP Server is Running!</h1>
    
    <div class="info">
        <p><strong>Server Time:</strong> <?php echo date('Y-m-d H:i:s'); ?></p>
        <p><strong>PHP Version:</strong> <?php echo phpversion(); ?></p>
        <p><strong>Document Root:</strong> <?php echo __DIR__; ?></p>
        <?php if (isset($_SERVER['REMOTE_ADDR'])): ?>
            <p><strong>Client IP:</strong> <?php echo $_SERVER['REMOTE_ADDR']; ?></p>
        <?php endif; ?>
    </div>
    
    <h2>🛠️ PHP Information</h2>
    <p><a href="info.php">View phpinfo()</a></p>
    
    <h2>📁 Directory Contents</h2>
    <ul>
        <?php
        $files = scandir('.');
        foreach ($files as $file) {
            if ($file != '.' && $file != '..') {
                echo "<li>$file</li>";
            }
        }
        ?>
    </ul>
</body>
</html>
EOF

        # 创建 phpinfo 页面
        cat > "$WEB_DIR/info.php" << 'EOF'
<?php phpinfo(); ?>
EOF
        success "默认页面创建完成"
    fi
}

# 配置自动启动
setup_autostart() {
    info "⚙️ 配置自动启动..."
    TARGET_FILE="$PREFIX/etc/bash.bashrc"
    MARKER="# Termux PHP Server Auto-start"
    
    # 移除旧配置
    if grep -q "$MARKER" "$TARGET_FILE"; then
        sed -i "/$MARKER/,/cd.*php.*8081/d" "$TARGET_FILE"
    fi
    
    # 添加新配置
    cat >> "$TARGET_FILE" << EOF

$MARKER
if ! pgrep -f "php -S 0.0.0.0:8081" > /dev/null; then
    cd '$WEB_DIR' && php -S 0.0.0.0:8081 > /dev/null 2>&1 &
    echo "🌐 PHP Server started automatically"
fi
EOF
}

# 启动服务
start_service() {
    info "🔛 启动 PHP 服务..."
    
    # 停止可能存在的旧服务
    pkill -f "php -S 0.0.0.0:8081" > /dev/null 2>&1 || true
    
    # 启动新服务
    cd "$WEB_DIR"
    nohup php -S 0.0.0.0:8081 > /dev/null 2>&1 &
    
    # 等待启动
    sleep 3
    
    # 检查是否启动成功
    if pgrep -f "php -S 0.0.0.0:8081" > /dev/null; then
        success "PHP 服务启动成功"
    else
        error "PHP 服务启动失败"
        exit 1
    fi
}

# 获取 IP 地址
get_ip() {
    local ip
    ip=$(ip route get 1.2.3.4 2>/dev/null | awk '{print $7}' | head -1)
    if [ -z "$ip" ]; then
        ip="127.0.0.1"
    fi
    echo "$ip"
}

# 显示结果
show_result() {
    IP_ADDRESS=$(get_ip)
    
    echo ""
    success "🎉 安装完成！"
    echo ""
    echo "📁 网站目录: $WEB_DIR"
    echo "🌐 本地访问: http://127.0.0.1:8081"
    echo "🌐 网络访问: http://$IP_ADDRESS:8081"
    echo ""
    echo "💡 使用说明:"
    echo "   - 将 PHP 文件放在网站目录即可访问"
    echo "   - 服务已设置为开机自启动"
    echo "   - 停止服务: pkill -f 'php -S'"
    echo "   - 重启服务: cd '$WEB_DIR' && php -S 0.0.0.0:8081"
    echo ""
    warning "⚠️  注意: 确保在安全网络环境下使用"
}

# 清理函数（可选）
cleanup() {
    if [ $? -ne 0 ]; then
        error "安装过程中出现错误"
    fi
}

# 设置退出时清理
trap cleanup EXIT

# 主执行流程
check_dependencies
main_install