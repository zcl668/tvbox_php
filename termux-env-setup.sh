#!/data/data/com.termux/files/usr/bin/bash

# --------------------------------------
# Termux 环境一键安装脚本
# 作者：木凡
# 功能：PHP 环境安装与自动启动 / Python 环境安装
# --------------------------------------

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 日志函数
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }
log_php() { echo -e "${CYAN}[PHP]${NC} $1"; }
log_python() { echo -e "${YELLOW}[PYTHON]${NC} $1"; }

check_success() {
    if [ $? -eq 0 ]; then
        log_info "$1 成功"
        return 0
    else
        log_warn "$1 失败"
        return 1
    fi
}

# PHP 环境安装
install_php() {
    log_step "开始安装 PHP 环境..."
    
    log_php "安装 PHP..."
    pkg install -y php
    check_success "PHP 安装"
    
    log_php "申请存储访问权限..."
    termux-setup-storage
    sleep 2
    
    log_php "创建网站目录..."
    mkdir -p /storage/emulated/0/TVBoxPhpJar/木凡/php
    check_success "网站目录创建"
    
    # 创建测试文件
    cat > /storage/emulated/0/TVBoxPhpJar/木凡/php/index.php << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Termux PHP Server</title>
    <meta charset="utf-8">
</head>
<body>
    <h1>✅ PHP 服务运行正常！</h1>
    <p>服务器时间: <?php echo date('Y-m-d H:i:s'); ?></p>
    <p>PHP版本: <?php echo phpversion(); ?></p>
    <p>目录: <?php echo __DIR__; ?></p>
</body>
</html>
<?php
echo "<!-- PHP测试完成 -->";
?>
EOF
    log_php "创建测试页面完成"
    
    log_php "配置自动启动..."
    TARGET_FILE="$PREFIX/etc/bash.bashrc"
    START_CMD="cd /storage/emulated/0/TVBoxPhpJar/木凡/php && php -S 0.0.0.0:8081 > /dev/null 2>&1 &"
    
    if ! grep -q "php -S 0.0.0.0:8081" "$TARGET_FILE"; then
        echo -e "\n# 自动启动PHP服务" >> "$TARGET_FILE"
        echo "$START_CMD" >> "$TARGET_FILE"
        echo "echo \"PHP服务已启动: http://\$(ip route get 1.2.3.4 | awk '{print \$7}' | head -1):8081\"" >> "$TARGET_FILE"
        log_php "自动启动配置已添加到 bash.bashrc"
    else
        log_php "自动启动配置已存在"
    fi
    
    # 立即启动 PHP 服务
    log_php "启动 PHP 服务..."
    eval "$START_CMD"
    
    log_info "✅ PHP 环境配置完成！"
    echo "📁 PHP根目录: /storage/emulated/0/TVBoxPhpJar/木凡/php"
    echo "🌐 访问地址: http://$(ip route get 1.2.3.4 | awk '{print $7}' | head -1):8081"
    echo "⏹️  停止服务: pkill php"
}

# 安装编译依赖
install_build_deps() {
    log_info "安装编译依赖..."
    
    build_packages=(
        "clang"
        "make" 
        "cmake"
        "binutils"
        "libffi"
        "openssl"
        "zlib"
        "libjpeg-turbo"
        "libxml2"
        "libxslt"
    )
    
    for package in "${build_packages[@]}"; do
        log_info "安装 $package..."
        pkg install -y "$package" 2>/dev/null
    done
    
    log_info "编译依赖安装完成"
}

# Python 基础安装
install_python_basic() {
    log_step "开始 Python 基础安装..."
    
    log_info "更新系统包..."
    pkg update -y && pkg upgrade -y
    check_success "系统包更新"
    
    log_info "安装核心组件..."
    pkg install -y python clang make git wget curl
    check_success "核心组件安装"
    
    install_build_deps
    
    log_info "设置 pip 镜像源..."
    pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple 2>/dev/null || {
        export PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple
    }
    log_info "pip 镜像源已设置"
    
    log_info "安装基础 Python 库..."
    basic_packages=(
        "requests" 
        "beautifulsoup4" 
        "lxml" 
        "psutil" 
        "pillow" 
        "colorama" 
        "pyyaml" 
        "click" 
        "tqdm"
    )
    
    for package in "${basic_packages[@]}"; do
        log_info "安装 $package..."
        pip install "$package" 2>/dev/null
        if [ $? -eq 0 ]; then
            log_info "✓ $package 安装成功"
        else
            log_warn "✗ $package 安装失败"
        fi
    done
    
    log_info "Python 基础安装完成"
}

# Python 完整安装
install_python_full() {
    install_python_basic
    
    log_step "开始 Python 完整安装..."
    
    log_info "安装数据科学库..."
    science_packages=(
        "numpy" 
        "pandas" 
        "matplotlib" 
        "scipy" 
        "scikit-learn" 
        "jupyter"
    )
    
    for package in "${science_packages[@]}"; do
        log_info "安装 $package..."
        pip install "$package" 2>/dev/null
        if [ $? -eq 0 ]; then
            log_info "✓ $package 安装成功"
        else
            log_warn "✗ $package 安装失败"
        fi
    done
    
    log_info "安装网络库..."
    network_packages=(
        "cryptography" 
        "paramiko" 
        "flask"
    )
    
    for package in "${network_packages[@]}"; do
        log_info "安装 $package..."
        pip install "$package" 2>/dev/null
        if [ $? -eq 0 ]; then
            log_info "✓ $package 安装成功"
        else
            log_warn "✗ $package 安装失败"
        fi
    done
    
    log_info "Python 完整安装完成"
}

# Python 最小安装
install_python_minimal() {
    log_step "开始 Python 最小安装..."
    
    log_info "更新系统包..."
    pkg update -y && pkg upgrade -y
    check_success "系统包更新"
    
    log_info "安装 Python..."
    pkg install -y python clang
    check_success "Python 安装"
    
    log_info "设置 pip 镜像源..."
    pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple 2>/dev/null || {
        export PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple
    }
    
    log_info "安装必要库..."
    minimal_packages=("requests" "psutil" "pillow")
    for package in "${minimal_packages[@]}"; do
        log_info "安装 $package..."
        pip install "$package" 2>/dev/null
        if [ $? -eq 0 ]; then
            log_info "✓ $package 安装成功"
        else
            log_warn "✗ $package 安装失败"
        fi
    done
    
    log_info "Python 最小安装完成"
}

# 验证 Python 安装
verify_python_installation() {
    log_step "验证 Python 安装..."
    
    echo "Python 版本: $(python --version 2>&1)"
    echo "Pip 版本: $(pip --version 2>/dev/null || echo '使用系统pip')"
    
    log_info "测试基础库导入..."
    python -c "
try:
    import requests, psutil, PIL
    print('✓ 基础库导入成功')
except ImportError as e:
    print(f'✗ 导入失败: {e}')
"
}

# 显示 Python 安装总结
show_python_summary() {
    log_info "=========================================="
    log_info "Python 环境安装完成！"
    log_info "现在你可以运行 Python 脚本了"
    echo ""
    log_info "常用命令:"
    echo "  python your_script.py    # 运行Python脚本"
    echo "  pip list                 # 查看已安装的包"
    echo "  pip install 包名         # 安装新包"
    log_info "=========================================="
}

# 显示主菜单
show_main_menu() {
    echo "=========================================="
    echo "Termux 环境一键安装脚本"
    echo "=========================================="
    echo "请选择安装选项："
    echo "1) 安装 PHP 环境 (Web服务器)"
    echo "2) 安装 Python 环境"
    echo "3) 安装 PHP + Python 完整环境"
    echo "4) 退出"
    echo -n "请输入选择 [1-4]: "
}

# 显示 Python 子菜单
show_python_menu() {
    echo "请选择 Python 安装模式："
    echo "1) 基础安装 (Python + 常用库)"
    echo "2) 完整安装 (基础 + 数据科学)"
    echo "3) 最小安装 (仅Python和必要库)"
    echo "4) 返回主菜单"
    echo -n "请输入选择 [1-4]: "
}

# 主函数
main() {
    while true; do
        show_main_menu
        read -r choice
        case $choice in
            1)
                install_php
                echo ""
                log_info "按回车键返回主菜单..."
                read -r
                ;;
            2)
                while true; do
                    show_python_menu
                    read -r python_choice
                    case $python_choice in
                        1)
                            install_python_basic
                            verify_python_installation
                            show_python_summary
                            break
                            ;;
                        2)
                            install_python_full
                            verify_python_installation
                            show_python_summary
                            break
                            ;;
                        3)
                            install_python_minimal
                            verify_python_installation
                            show_python_summary
                            break
                            ;;
                        4)
                            break
                            ;;
                        *)
                            log_error "无效选择，请重新输入"
                            ;;
                    esac
                done
                echo ""
                log_info "按回车键返回主菜单..."
                read -r
                ;;
            3)
                install_php
                echo ""
                while true; do
                    show_python_menu
                    read -r python_choice
                    case $python_choice in
                        1)
                            install_python_basic
                            verify_python_installation
                            show_python_summary
                            break
                            ;;
                        2)
                            install_python_full
                            verify_python_installation
                            show_python_summary
                            break
                            ;;
                        3)
                            install_python_minimal
                            verify_python_installation
                            show_python_summary
                            break
                            ;;
                        4)
                            break
                            ;;
                        *)
                            log_error "无效选择，请重新输入"
                            ;;
                    esac
                done
                echo ""
                log_info "按回车键返回主菜单..."
                read -r
                ;;
            4)
                log_info "退出安装脚本"
                exit 0
                ;;
            *)
                log_error "无效选择，请重新输入"
                ;;
        esac
    done
}

# 显示欢迎信息
echo "=========================================="
echo "Termux 环境一键安装脚本"
echo "作者：木凡"
echo "功能：PHP Web 环境 + Python 开发环境"
echo "=========================================="

# 运行主函数
main "$@"
