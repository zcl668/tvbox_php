#!/bin/bash
# ============================================================
# php_tvbox.sh
# 适配 armv8l (64位CPU运行32位系统) 的电视盒子
# 自动检测并选择合适的架构
# 按回车键确认打包，无需键盘输入 y/n
# ============================================================

set -e

# ---------- 颜色定义 ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# ---------- 检测实际兼容架构 ----------
detect_compatible_arch() {
    MACHINE=$(uname -m)
    
    case "$MACHINE" in
        aarch64)
            CURRENT_ARCH="arm64-v8a"
            RECOMMEND_ARCH="arm64-v8a"
            TERMUX_LIB_PATH="aarch64"
            ARCH_DESC="纯64位系统"
            ;;
        armv8l)
            CURRENT_ARCH="armv8l"
            # armv8l 是64位CPU运行32位系统，推荐使用 armeabi-v7a
            RECOMMEND_ARCH="armeabi-v7a"
            TERMUX_LIB_PATH="arm"
            ARCH_DESC="64位CPU运行32位系统 (电视盒子常见)"
            ;;
        armv7l)
            CURRENT_ARCH="armeabi-v7a"
            RECOMMEND_ARCH="armeabi-v7a"
            TERMUX_LIB_PATH="arm"
            ARCH_DESC="32位系统"
            ;;
        x86_64)
            CURRENT_ARCH="x86_64"
            RECOMMEND_ARCH="x86_64"
            TERMUX_LIB_PATH="x86_64"
            ARCH_DESC="64位x86系统"
            ;;
        i686)
            CURRENT_ARCH="x86"
            RECOMMEND_ARCH="x86"
            TERMUX_LIB_PATH="i686"
            ARCH_DESC="32位x86系统"
            ;;
        *)
            CURRENT_ARCH="$MACHINE"
            RECOMMEND_ARCH="$MACHINE"
            TERMUX_LIB_PATH="$MACHINE"
            ARCH_DESC="未知架构"
            ;;
    esac
    
    # 目标架构固定为推荐的架构
    TARGET_ARCH="$RECOMMEND_ARCH"
}

# ---------- 初始化 ----------
init_vars() {
    detect_compatible_arch
    
    echo -e "${CYAN}================================================${NC}"
    echo -e "${YELLOW}当前设备架构: ${CURRENT_ARCH}${NC}"
    echo -e "${YELLOW}架构说明: ${ARCH_DESC}${NC}"
    echo -e "${YELLOW}推荐打包架构: ${RECOMMEND_ARCH} (电视盒子优化版)${NC}"
    echo -e "${CYAN}================================================${NC}"
    
    # 获取 PHP 版本
    if ! command -v php >/dev/null 2>&1; then
        echo -e "${RED}错误: 未找到 php 命令${NC}"
        echo -e "${YELLOW}请安装 PHP: pkg install php${NC}"
        exit 1
    fi
    
    PHP_VER=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;" 2>/dev/null)
    PHP_FULL=$(php --version 2>/dev/null | head -1 | awk '{print $2}')
    
    if [ -z "$PHP_FULL" ]; then
        echo -e "${RED}错误: 无法检测 PHP 版本${NC}"
        exit 1
    fi
    
    # 输出路径
    OUTPUT_DIR="/storage/emulated/0/编程学习"
    OUTPUT_NAME="php-${PHP_FULL}-tvbox-${TARGET_ARCH}.zip"
    OUTPUT_PATH="${OUTPUT_DIR}/${OUTPUT_NAME}"
    
    # Termux 路径
    TERMUX_PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
    
    # 工作目录
    WORKDIR="$HOME/php_tvbox_repack"
    TEST_DIR="$HOME/php_tvbox_test"
}

# ---------- 检查存储权限 ----------
check_storage() {
    echo -e "${YELLOW}检查存储权限...${NC}"
    if [ ! -d "$HOME/storage/shared" ]; then
        echo -e "${BLUE}正在设置存储权限...${NC}"
        termux-setup-storage
        sleep 3
    fi
    mkdir -p "$OUTPUT_DIR"
}

# ---------- 检测环境 ----------
check_environment() {
    echo -e "${CYAN}================================================${NC}"
    echo -e "${GREEN}检测 PHP 打包环境${NC}"
    echo -e "${CYAN}================================================${NC}"
    
    echo -e "${GREEN}✓ PHP 版本: ${PHP_FULL}${NC}"
    echo -e "${GREEN}✓ 当前架构: ${CURRENT_ARCH}${NC}"
    echo -e "${GREEN}✓ 目标架构: ${TARGET_ARCH}${NC}"
    
    # 检查必要的工具
    if ! command -v readelf >/dev/null 2>&1; then
        echo -e "${YELLOW}警告: 未安装 readelf，建议安装: pkg install binutils${NC}"
    fi
    
    if ! command -v zip >/dev/null 2>&1; then
        echo -e "${YELLOW}警告: 未安装 zip，建议安装: pkg install zip${NC}"
    fi
    
    # 针对 armv8l 的特殊提示
    if [ "$CURRENT_ARCH" = "armv8l" ]; then
        echo -e "${YELLOW}注意: 您的设备是 armv8l (64位CPU运行32位系统)${NC}"
        echo -e "${YELLOW}将打包 ${TARGET_ARCH} 版本以获得最佳兼容性${NC}"
    fi
    
    # 如果当前架构不等于目标架构，显示提示
    if [ "$CURRENT_ARCH" != "$TARGET_ARCH" ] && [ "$CURRENT_ARCH" != "armv8l" ]; then
        echo -e "${YELLOW}注意: 当前架构 ${CURRENT_ARCH} 与目标架构 ${TARGET_ARCH} 不同${NC}"
        echo -e "${YELLOW}将使用当前设备的库文件，可能与目标架构不完全兼容${NC}"
    fi
}

# ---------- 递归收集依赖库 ----------
collect_all_deps() {
    local binary="$1"
    local deps=""
    
    if command -v readelf >/dev/null 2>&1; then
        deps=$(readelf -d "$binary" 2>/dev/null | grep 'NEEDED' | sed -n 's/.*\[\(.*\)\].*/\1/p')
    fi
    
    for dep in $deps; do
        echo "$dep"
        dep_path=$(find "${TERMUX_PREFIX}/lib" -name "$dep" 2>/dev/null | head -1)
        if [ -n "$dep_path" ] && [ -f "$dep_path" ]; then
            collect_all_deps "$dep_path"
        fi
    done
}

# ---------- 检查文件架构 ----------
check_file_arch() {
    local file="$1"
    if command -v readelf >/dev/null 2>&1; then
        local arch_info=$(readelf -h "$file" 2>/dev/null | grep 'Machine' || true)
        echo "$arch_info"
    fi
}

# ---------- 开始打包 ----------
start_packaging() {
    clear
    echo -e "${CYAN}================================================${NC}"
    echo -e "${GREEN}开始打包 PHP ${PHP_FULL} for ${TARGET_ARCH}${NC}"
    echo -e "${CYAN}================================================${NC}"
    
    # 清理并创建目录
    rm -rf "$WORKDIR" "$TEST_DIR"
    mkdir -p "$WORKDIR/bin"
    mkdir -p "$WORKDIR/lib"
    mkdir -p "$WORKDIR/etc"
    mkdir -p "$WORKDIR/lib/php"
    mkdir -p "$TEST_DIR"
    
    echo -e "${GREEN}  ✓ 目录创建完成${NC}"
    
    # ----- 1. 复制 PHP 二进制 -----
    echo -e "${BLUE}[1/7] 复制 PHP 二进制...${NC}"
    PHP_BIN=$(command -v php)
    cp "$PHP_BIN" "$WORKDIR/bin/php"
    chmod 755 "$WORKDIR/bin/php"
    echo -e "${GREEN}  ✓ 已复制: $PHP_BIN${NC}"
    
    # 检查二进制架构
    FILE_ARCH=$(check_file_arch "$PHP_BIN")
    echo -e "${YELLOW}  PHP 二进制架构: ${FILE_ARCH:-未知}${NC}"
    
    # 创建链接
    cd "$WORKDIR/bin"
    ln -sf php php-cgi 2>/dev/null || true
    ln -sf php phar 2>/dev/null || true
    cd "$HOME"
    
    # ----- 2. 复制 PHP 扩展 -----
    echo -e "${BLUE}[2/7] 复制 PHP 扩展...${NC}"
    EXT_DIR="${TERMUX_PREFIX}/lib/php"
    if [ -d "$EXT_DIR" ]; then
        cp -r "$EXT_DIR/"* "$WORKDIR/lib/php/" 2>/dev/null || true
        EXT_COUNT=$(find "$WORKDIR/lib/php" -name "*.so" 2>/dev/null | wc -l)
        echo -e "${GREEN}  ✓ 已复制 $EXT_COUNT 个扩展${NC}"
        
        # 显示前几个扩展的架构信息
        if [ $EXT_COUNT -gt 0 ]; then
            echo -e "${YELLOW}  扩展架构示例:${NC}"
            for SO in $(find "$WORKDIR/lib/php" -name "*.so" 2>/dev/null | head -3); do
                SO_ARCH=$(check_file_arch "$SO")
                echo -e "    $(basename $SO): ${SO_ARCH:-未知}"
            done
        fi
    fi
    
    # ----- 3. 复制配置文件 -----
    echo -e "${BLUE}[3/7] 复制配置文件...${NC}"
    if [ -d "${TERMUX_PREFIX}/etc/php" ]; then
        cp -r "${TERMUX_PREFIX}/etc/php" "$WORKDIR/etc/" 2>/dev/null || true
        echo -e "${GREEN}  ✓ 配置目录复制完成${NC}"
    fi
    
    # ----- 4. 收集依赖库 -----
    echo -e "${BLUE}[4/7] 收集依赖库...${NC}"
    
    # 收集 PHP 二进制依赖
    ALL_DEPS=$(collect_all_deps "$WORKDIR/bin/php" | sort -u)
    
    # 收集扩展依赖
    if [ -d "$WORKDIR/lib/php" ]; then
        for SO in $(find "$WORKDIR/lib/php" -name "*.so" 2>/dev/null); do
            ALL_DEPS="$ALL_DEPS"$'\n'"$(collect_all_deps "$SO")"
        done
    fi
    
    ALL_DEPS=$(echo "$ALL_DEPS" | sort -u | grep -v '^$')
    
    # 复制依赖库 - 优先使用 arm 架构的库（针对 armv8l）
    for LIB in $ALL_DEPS; do
        if [ ! -f "$WORKDIR/lib/$LIB" ]; then
            # 优先查找对应架构的库
            LIB_PATH=""
            
            # 针对 armv8l，优先查找 arm 目录
            if [ "$CURRENT_ARCH" = "armv8l" ]; then
                LIB_PATH=$(find "${TERMUX_PREFIX}/lib/arm" -name "$LIB" 2>/dev/null | head -1)
            fi
            
            # 如果没找到，使用 TERMUX_LIB_PATH
            if [ -z "$LIB_PATH" ] && [ -n "$TERMUX_LIB_PATH" ]; then
                LIB_PATH=$(find "${TERMUX_PREFIX}/lib/$TERMUX_LIB_PATH" -name "$LIB" 2>/dev/null | head -1)
            fi
            
            # 最后在 lib 目录下查找
            if [ -z "$LIB_PATH" ]; then
                LIB_PATH=$(find "${TERMUX_PREFIX}/lib" -name "$LIB" 2>/dev/null | head -1)
            fi
            
            if [ -n "$LIB_PATH" ] && [ -f "$LIB_PATH" ]; then
                cp "$LIB_PATH" "$WORKDIR/lib/"
                echo -e "${GREEN}  ✓ 复制: $LIB${NC}"
            fi
        fi
    done
    
    # ----- 5. 复制基础系统库（针对电视盒子优化）-----
    echo -e "${BLUE}[5/7] 复制基础系统库...${NC}"
    
    # 电视盒子需要的基础库
    BASE_LIBS="
        libc.so
        libm.so
        libdl.so
        libpthread.so
        libresolv.so
        librt.so
        libstdc++.so
        libgcc_s.so
        libc++_shared.so
        libssl.so
        libcrypto.so
        libz.so
        libxml2.so
        libicuuc.so
        libicui18n.so
        libicudata.so
        libsqlite3.so
        libcurl.so
        libonig.so
        libbz2.so
        liblzma.so
        libexpat.so
        libreadline.so
        libncursesw.so
    "
    
    for LIB in $BASE_LIBS; do
        if [ ! -f "$WORKDIR/lib/$LIB" ]; then
            # 优先查找对应架构的库
            LIB_PATH=""
            
            # 针对 armv8l，优先查找 arm 目录
            if [ "$CURRENT_ARCH" = "armv8l" ]; then
                LIB_PATH=$(find "${TERMUX_PREFIX}/lib/arm" -name "$LIB" 2>/dev/null | head -1)
            fi
            
            if [ -z "$LIB_PATH" ] && [ -n "$TERMUX_LIB_PATH" ]; then
                LIB_PATH=$(find "${TERMUX_PREFIX}/lib/$TERMUX_LIB_PATH" -name "$LIB" 2>/dev/null | head -1)
            fi
            
            if [ -z "$LIB_PATH" ]; then
                LIB_PATH=$(find "${TERMUX_PREFIX}/lib" -name "$LIB" 2>/dev/null | head -1)
            fi
            
            if [ -n "$LIB_PATH" ] && [ -f "$LIB_PATH" ]; then
                cp "$LIB_PATH" "$WORKDIR/lib/" 2>/dev/null && echo -e "${GREEN}  ✓ 复制: $LIB${NC}"
            fi
        fi
    done
    
    # ----- 6. 生成 php.ini -----
    echo -e "${BLUE}[6/7] 生成 php.ini...${NC}"
    
    cat > "$WORKDIR/etc/php.ini" << 'EOF'
[PHP]
engine = On
short_open_tag = On
precision = 14
output_buffering = 4096
zlib.output_compression = Off
implicit_flush = Off
unserialize_callback_func =
serialize_precision = -1
disable_functions = exec,passthru,shell_exec,system,proc_open,popen
disable_classes =
zend.enable_gc = On
expose_php = Off
max_execution_time = 300
max_input_time = 60
memory_limit = 128M
error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT
display_errors = Off
display_startup_errors = Off
log_errors = On
log_errors_max_len = 1024
ignore_repeated_errors = Off
ignore_repeated_source = Off
report_memleaks = On
html_errors = Off
variables_order = "GPCS"
request_order = "GP"
register_argc_argv = Off
auto_globals_jit = On
post_max_size = 50M
auto_prepend_file =
auto_append_file =
default_mimetype = "text/html"
default_charset = "UTF-8"
doc_root =
user_dir =
enable_dl = Off
file_uploads = On
upload_max_filesize = 50M
max_file_uploads = 20
allow_url_fopen = On
allow_url_include = Off
default_socket_timeout = 60
extension_dir = "lib/php"
date.timezone = Asia/Shanghai

[CLI Server]
cli_server.color = On

[mysqlnd]
mysqlnd.collect_statistics = Off
mysqlnd.collect_memory_statistics = Off

[curl]
curl.cainfo =

[openssl]
openssl.cafile =
EOF

    # 添加扩展加载
    if [ -d "$WORKDIR/lib/php" ]; then
        echo "" >> "$WORKDIR/etc/php.ini"
        echo "; 自动加载扩展" >> "$WORKDIR/etc/php.ini"
        for SO_FILE in $(find "$WORKDIR/lib/php" -name "*.so" 2>/dev/null | sort); do
            EXT_NAME=$(basename "$SO_FILE" .so)
            echo "extension=${EXT_NAME}" >> "$WORKDIR/etc/php.ini"
        done
    fi
    
    echo -e "${GREEN}  ✓ php.ini 生成完成${NC}"
    
    # ----- 7. 创建启动脚本 -----
    echo -e "${BLUE}[7/7] 创建启动脚本...${NC}"
    
    # 创建 PHP 启动脚本
    cat > "$WORKDIR/bin/php-tv" << 'EOF'
#!/system/bin/sh
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
export LD_LIBRARY_PATH="$BASE_DIR/lib:/system/lib:/vendor/lib:$LD_LIBRARY_PATH"
export PHPRC="$BASE_DIR/etc/php.ini"
export PHP_INI_SCAN_DIR="$BASE_DIR/etc/php"
exec "$SCRIPT_DIR/php" "$@"
EOF
    chmod 755 "$WORKDIR/bin/php-tv"
    
    # 创建测试脚本
    cat > "$WORKDIR/test.php" << 'EOF'
<?php
echo "PHP Version: " . phpversion() . "\n";
echo "PHP Info:\n";
echo "----------------------------------------\n";
echo "Loaded Extensions: " . implode(", ", get_loaded_extensions()) . "\n";
echo "----------------------------------------\n";
echo "Test: 1+2=" . (1+2) . "\n";
?>
EOF
    
    # 创建架构信息文件
    cat > "$WORKDIR/arch-info.txt" << EOF
打包架构信息:
- 检测到的架构: ${CURRENT_ARCH}
- 架构说明: ${ARCH_DESC}
- 目标打包架构: ${TARGET_ARCH}
- 打包日期: $(date)
- PHP 版本: ${PHP_FULL}

注意: 此包专为 ${TARGET_ARCH} 架构优化
EOF
    
    # 创建 README
    cat > "$WORKDIR/README.txt" << EOF
PHP ${PHP_FULL} for Android TV Box (${TARGET_ARCH})

使用说明:
1. 解压到电视盒子目录 (如 /sdcard/php)
2. 运行: cd /sdcard/php && ./bin/php-tv test.php
3. 或者: ./bin/php-tv 你的脚本.php

环境变量:
- LD_LIBRARY_PATH: lib:/system/lib:/vendor/lib
- PHPRC: etc/php.ini

包含扩展:
$(find "$WORKDIR/lib/php" -name "*.so" 2>/dev/null | xargs -n1 basename | sed 's/\.so$//' | tr '\n' ' ')

打包信息:
- 检测到的架构: ${CURRENT_ARCH}
- 目标架构: ${TARGET_ARCH}
- 打包日期: $(date)
EOF
    
    echo -e "${GREEN}  ✓ 脚本创建完成${NC}"
    
    # ----- 8. 测试打包的 PHP -----
    echo -e "${BLUE}[8/7] 测试打包的 PHP...${NC}"
    cp -r "$WORKDIR/"* "$TEST_DIR/"
    
    # 设置测试环境
    export TEST_LD_LIBRARY_PATH="$TEST_DIR/lib:/system/lib:/vendor/lib"
    export TEST_PHPRC="$TEST_DIR/etc/php.ini"
    
    echo -e "${YELLOW}  运行测试脚本...${NC}"
    
    # 尝试运行 PHP
    if env -i LD_LIBRARY_PATH="$TEST_LD_LIBRARY_PATH" PHPRC="$TEST_PHPRC" "$TEST_DIR/bin/php" test.php > "$TEST_DIR/test-output.log" 2>&1; then
        echo -e "${GREEN}  ✓ PHP 测试通过${NC}"
        echo -e "${GREEN}  ✓ $(env -i LD_LIBRARY_PATH="$TEST_LD_LIBRARY_PATH" "$TEST_DIR/bin/php" --version | head -1)${NC}"
    else
        echo -e "${RED}  ✗ PHP 测试失败${NC}"
        echo -e "${YELLOW}  错误信息:${NC}"
        tail -5 "$TEST_DIR/test-output.log"
        
        # 尝试直接运行查看错误
        echo -e "${YELLOW}  尝试直接运行:${NC}"
        env -i LD_LIBRARY_PATH="$TEST_LD_LIBRARY_PATH" "$TEST_DIR/bin/php" --version 2>&1 || true
        
        echo ""
        echo -e "${YELLOW}测试失败，按回车键继续打包，或按 Ctrl+C 取消${NC}"
        read -p ""
    fi
    
    # ----- 9. 打包为 ZIP -----
    echo -e "${BLUE}[9/7] 打包为 ZIP...${NC}"
    cd "$WORKDIR"
    zip -ry "$OUTPUT_PATH" ./* > /dev/null
    cd "$HOME"
    
    ZIP_SIZE=$(du -h "$OUTPUT_PATH" | cut -f1)
    ZIP_FILES=$(unzip -l "$OUTPUT_PATH" 2>/dev/null | wc -l)
    
    echo -e "${CYAN}================================================${NC}"
    echo -e "${GREEN}✅ 打包完成！${NC}"
    echo -e "  文件: ${YELLOW}${OUTPUT_PATH}${NC}"
    echo -e "  大小: ${YELLOW}${ZIP_SIZE}${NC}"
    echo -e "  文件数: ${YELLOW}${ZIP_FILES}${NC}"
    echo -e "  检测架构: ${YELLOW}${CURRENT_ARCH}${NC}"
    echo -e "  目标架构: ${YELLOW}${TARGET_ARCH}${NC}"
    echo -e "${CYAN}================================================${NC}"
    echo ""
    echo -e "${PURPLE}lab.json 配置:${NC}"
    echo '  {'
    echo "    \"name\": \"php\","
    echo "    \"group\": \"runtime\","
    echo "    \"version\": \"${PHP_FULL}\","
    echo "    \"binary_path\": \"bin/php-tv\","
    echo "    \"var_path\": {"
    echo "      \"PATH\": \"bin\","
    echo "      \"LD_LIBRARY_PATH\": \"lib:/system/lib:/vendor/lib\","
    echo "      \"PHPRC\": \"etc/php.ini\""
    echo "    },"
    echo "    \"downloads\": ["
    echo "      {"
    echo "        \"arch\": \"${TARGET_ARCH}\","
    echo "        \"url\": \"你的上传地址\","
    echo "        \"size\": \"${ZIP_SIZE}\""
    echo "      }"
    echo "    ]"
    echo '  }'
    echo -e "${CYAN}================================================${NC}"
    
    # 清理临时文件
    echo ""
    echo -e "${YELLOW}按回车键清理临时文件，或按 Ctrl+C 保留${NC}"
    read -p ""
    rm -rf "$WORKDIR" "$TEST_DIR"
    echo -e "${GREEN}✓ 已清理临时文件${NC}"
}

# ---------- 主函数 ----------
main() {
    init_vars
    check_storage
    check_environment
    
    echo ""
    echo -e "${YELLOW}按回车键开始打包，或按 Ctrl+C 取消${NC}"
    read -p ""
    start_packaging
}

main "$@"