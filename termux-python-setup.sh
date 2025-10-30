#!/data/data/com.termux/files/usr/bin/bash

echo "=========================================="
echo "Termux Python 环境一键安装脚本 (Termux专用版)"
echo "=========================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 日志函数
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

check_success() {
    if [ $? -eq 0 ]; then
        log_info "$1 成功"
        return 0
    else
        log_warn "$1 失败"
        return 1
    fi
}

# 显示菜单
show_menu() {
    echo "请选择安装模式："
    echo "1) 基础安装 (Python + 常用库)"
    echo "2) 完整安装 (基础 + 数据科学)"
    echo "3) 最小安装 (仅Python和必要库)"
    echo "4) 退出"
    echo -n "请输入选择 [1-4]: "
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

# 基础安装
install_basic() {
    log_step "开始基础安装..."
    
    log_info "更新系统包..."
    pkg update -y && pkg upgrade -y
    check_success "系统包更新"
    
    log_info "安装核心组件..."
    pkg install -y python clang make git wget curl
    check_success "核心组件安装"
    
    # 安装编译依赖
    install_build_deps
    
    log_info "设置 pip 镜像源..."
    pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple 2>/dev/null || {
        # 如果 pip config 失败，使用环境变量
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
    
    log_info "基础安装完成"
    return 0
}

# 完整安装
install_full() {
    install_basic
    
    log_step "开始完整安装..."
    
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
    
    log_info "完整安装完成"
    return 0
}

# 最小安装
install_minimal() {
    log_step "开始最小安装..."
    
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
    
    log_info "最小安装完成"
    return 0
}

# 验证安装
verify_installation() {
    log_step "验证安装..."
    
    echo "Python 版本: $(python --version 2>&1)"
    echo "Pip 版本: $(pip --version 2>/dev/null || echo '使用系统pip')"
    
    log_info "测试基础库导入..."
    python -c "
try:
    import requests, psutil
    print('✓ 基础库导入成功')
except ImportError as e:
    print(f'✗ 导入失败: {e}')
"
}

# 显示安装总结
show_summary() {
    log_info "=========================================="
    log_info "安装完成！"
    log_info "现在你可以运行 Python 脚本了"
    echo ""
    log_info "常用命令:"
    echo "  python your_script.py    # 运行Python脚本"
    echo "  pip list                 # 查看已安装的包"
    echo "  pip install 包名         # 安装新包"
    log_info "=========================================="
}

# 主函数
main() {
    echo "Termux Python 环境一键安装脚本"
    echo "完全适配 Termux 限制"
    echo "=========================================="
    
    while true; do
        show_menu
        read -r choice
        case $choice in
            1)
                install_basic
                verify_installation
                show_summary
                break
                ;;
            2)
                install_full
                verify_installation
                show_summary
                break
                ;;
            3)
                install_minimal
                verify_installation
                show_summary
                break
                ;;
            4)
                log_info "退出安装"
                exit 0
                ;;
            *)
                log_error "无效选择，请重新输入"
                ;;
        esac
    done
}

# 运行主函数
main "$@"