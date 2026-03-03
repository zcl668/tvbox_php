#!/bin/bash
# ============================================================
# python_tvbox.sh
# 支持在 arm64 设备上打包 armeabi-v7a 版本的 Python
# 打包为 ZIP 压缩包
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

# ---------- 初始化 ----------
init_vars() {
    # 检测当前设备架构
    MACHINE=$(uname -m)
    case "$MACHINE" in
        aarch64)  
            CURRENT_ARCH="arm64-v8a"
            TERMUX_LIB_PATH="aarch64"
            ;;
        armv7l)   
            CURRENT_ARCH="armeabi-v7a"
            TERMUX_LIB_PATH="arm"
            ;;
        x86_64)   
            CURRENT_ARCH="x86_64"
            TERMUX_LIB_PATH="x86_64"
            ;;
        i686)     
            CURRENT_ARCH="x86"
            TERMUX_LIB_PATH="i686"
            ;;
        *)        
            CURRENT_ARCH="$MACHINE"
            TERMUX_LIB_PATH="$MACHINE"
            ;;
    esac
    
    # 目标架构固定为 armeabi-v7a
    TARGET_ARCH="armeabi-v7a"
    
    echo -e "${CYAN}================================================${NC}"
    echo -e "${YELLOW}当前设备架构: ${CURRENT_ARCH}${NC}"
    echo -e "${YELLOW}目标打包架构: ${TARGET_ARCH} (电视盒子优化版)${NC}"
    echo -e "${CYAN}================================================${NC}"
    
    # 获取 Python 版本
    if ! command -v python3 >/dev/null 2>&1; then
        echo -e "${RED}错误: 未找到 python3 命令${NC}"
        echo -e "${YELLOW}请安装 Python: pkg install python${NC}"
        exit 1
    fi
    
    PYTHON_VER=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null)
    PYTHON_FULL=$(python3 --version 2>/dev/null | awk '{print $2}')
    
    if [ -z "$PYTHON_FULL" ]; then
        echo -e "${RED}错误: 无法检测 Python 版本${NC}"
        exit 1
    fi
    
    # 输出路径
    OUTPUT_DIR="/storage/emulated/0/编程学习"
    OUTPUT_NAME="python-${PYTHON_FULL}-tvbox-${TARGET_ARCH}.zip"
    OUTPUT_PATH="${OUTPUT_DIR}/${OUTPUT_NAME}"
    
    # Termux 路径
    TERMUX_PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
    
    # 工作目录
    WORKDIR="$HOME/python_tvbox_repack"
    TEST_DIR="$HOME/python_tvbox_test"
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
    echo -e "${GREEN}检测 Python 打包环境${NC}"
    echo -e "${CYAN}================================================${NC}"
    
    echo -e "${GREEN}✓ Python 版本: ${PYTHON_FULL}${NC}"
    echo -e "${GREEN}✓ 当前架构: ${CURRENT_ARCH}${NC}"
    echo -e "${GREEN}✓ 目标架构: ${TARGET_ARCH}${NC}"
    
    # 检查 pip
    if command -v pip3 >/dev/null 2>&1; then
        PIP_VER=$(pip3 --version 2>/dev/null | awk '{print $2}')
        echo -e "${GREEN}✓ pip 版本: ${PIP_VER}${NC}"
    fi
    
    # 检查必要的工具
    if ! command -v readelf >/dev/null 2>&1; then
        echo -e "${YELLOW}警告: 未安装 readelf，建议安装: pkg install binutils${NC}"
    fi
    
    if ! command -v zip >/dev/null 2>&1; then
        echo -e "${YELLOW}警告: 未安装 zip，建议安装: pkg install zip${NC}"
    fi
    
    # 如果是 arm64 架构，显示提示
    if [ "$CURRENT_ARCH" = "arm64-v8a" ]; then
        echo -e "${YELLOW}注意: 在 arm64 设备上打包 armeabi-v7a 版本${NC}"
        echo -e "${YELLOW}将使用当前设备的库文件，可能与目标架构不完全兼容${NC}"
        echo -e "${YELLOW}建议在真实的 armeabi-v7a 设备上打包以获得最佳兼容性${NC}"
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
    echo -e "${GREEN}开始打包 Python ${PYTHON_FULL} for ${TARGET_ARCH}${NC}"
    echo -e "${CYAN}================================================${NC}"
    
    # 清理并创建目录
    rm -rf "$WORKDIR" "$TEST_DIR"
    mkdir -p "$WORKDIR/bin"
    mkdir -p "$WORKDIR/lib"
    mkdir -p "$WORKDIR/lib/python${PYTHON_VER}"
    mkdir -p "$TEST_DIR"
    
    echo -e "${GREEN}  ✓ 目录创建完成${NC}"
    
    # ----- 1. 复制 Python 二进制 -----
    echo -e "${BLUE}[1/8] 复制 Python 二进制...${NC}"
    PYTHON_BIN=$(command -v python3)
    cp "$PYTHON_BIN" "$WORKDIR/bin/python3"
    chmod 755 "$WORKDIR/bin/python3"
    
    # 检查二进制架构
    if [ "$CURRENT_ARCH" != "$TARGET_ARCH" ]; then
        FILE_ARCH=$(check_file_arch "$PYTHON_BIN")
        echo -e "${YELLOW}  ⚠ Python 二进制架构: ${FILE_ARCH:-未知}${NC}"
    fi
    
    cd "$WORKDIR/bin"
    ln -sf python3 python
    ln -sf python3 python3.${PYTHON_VER#*.} 2>/dev/null || true
    cd "$HOME"
    echo -e "${GREEN}  ✓ 已复制: $PYTHON_BIN${NC}"
    
    # 复制 pip
    if command -v pip3 >/dev/null 2>&1; then
        PIP_BIN=$(command -v pip3)
        cp "$PIP_BIN" "$WORKDIR/bin/pip3" 2>/dev/null || true
        cd "$WORKDIR/bin" && ln -sf pip3 pip 2>/dev/null || true && cd "$HOME"
        echo -e "${GREEN}  ✓ 已复制: pip${NC}"
    fi
    
    # ----- 2. 复制标准库 -----
    echo -e "${BLUE}[2/8] 复制 Python 标准库...${NC}"
    STDLIB_DIR="${TERMUX_PREFIX}/lib/python${PYTHON_VER}"
    if [ -d "$STDLIB_DIR" ]; then
        cp -r "$STDLIB_DIR" "$WORKDIR/lib/"
        echo -e "${GREEN}  ✓ 标准库复制完成${NC}"
    else
        echo -e "${RED}  ✗ 找不到标准库目录: $STDLIB_DIR${NC}"
        exit 1
    fi
    
    # ----- 3. 复制动态模块 -----
    echo -e "${BLUE}[3/8] 复制动态模块...${NC}"
    DYNLOAD_DIR="${TERMUX_PREFIX}/lib/python${PYTHON_VER}/lib-dynload"
    if [ -d "$DYNLOAD_DIR" ]; then
        cp -r "$DYNLOAD_DIR" "$WORKDIR/lib/python${PYTHON_VER}/"
        MOD_COUNT=$(find "$WORKDIR/lib/python${PYTHON_VER}/lib-dynload" -name "*.so" 2>/dev/null | wc -l)
        echo -e "${GREEN}  ✓ 已复制 $MOD_COUNT 个动态模块${NC}"
        
        # 显示前几个模块的架构信息
        if [ "$CURRENT_ARCH" != "$TARGET_ARCH" ] && [ $MOD_COUNT -gt 0 ]; then
            echo -e "${YELLOW}  ⚠ 模块架构示例:${NC}"
            for SO in $(find "$WORKDIR/lib/python${PYTHON_VER}/lib-dynload" -name "*.so" 2>/dev/null | head -3); do
                SO_ARCH=$(check_file_arch "$SO")
                echo -e "    $(basename $SO): ${SO_ARCH:-未知}"
            done
        fi
    fi
    
    # ----- 4. 精简标准库 -----
    echo -e "${BLUE}[4/8] 精简标准库...${NC}"
    
    # 删除不必要的模块
    rm -rf "$WORKDIR/lib/python${PYTHON_VER}/test"
    rm -rf "$WORKDIR/lib/python${PYTHON_VER}/idlelib"
    rm -rf "$WORKDIR/lib/python${PYTHON_VER}/tkinter"
    rm -rf "$WORKDIR/lib/python${PYTHON_VER}/turtledemo"
    rm -rf "$WORKDIR/lib/python${PYTHON_VER}/distutils/command" 2>/dev/null || true
    
    # 删除缓存文件
    find "$WORKDIR/lib/python${PYTHON_VER}" -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
    find "$WORKDIR/lib/python${PYTHON_VER}" -name "*.pyc" -delete 2>/dev/null || true
    find "$WORKDIR/lib/python${PYTHON_VER}" -name "*.pyo" -delete 2>/dev/null || true
    
    echo -e "${GREEN}  ✓ 精简完成${NC}"
    
    # ----- 5. 收集依赖库 -----
    echo -e "${BLUE}[5/8] 收集依赖库...${NC}"
    
    # 收集 Python 二进制依赖
    ALL_DEPS=$(collect_all_deps "$WORKDIR/bin/python3" | sort -u)
    
    # 收集动态模块依赖
    if [ -d "$WORKDIR/lib/python${PYTHON_VER}/lib-dynload" ]; then
        for SO in $(find "$WORKDIR/lib/python${PYTHON_VER}/lib-dynload" -name "*.so" 2>/dev/null); do
            ALL_DEPS="$ALL_DEPS"$'\n'"$(collect_all_deps "$SO")"
        done
    fi
    
    ALL_DEPS=$(echo "$ALL_DEPS" | sort -u | grep -v '^$')
    
    # 复制依赖库
    for LIB in $ALL_DEPS; do
        if [ ! -f "$WORKDIR/lib/$LIB" ]; then
            # 优先查找对应架构的库
            LIB_PATH=""
            if [ -n "$TERMUX_LIB_PATH" ]; then
                LIB_PATH=$(find "${TERMUX_PREFIX}/lib/$TERMUX_LIB_PATH" -name "$LIB" 2>/dev/null | head -1)
            fi
            if [ -z "$LIB_PATH" ]; then
                LIB_PATH=$(find "${TERMUX_PREFIX}/lib" -name "$LIB" 2>/dev/null | head -1)
            fi
            if [ -n "$LIB_PATH" ] && [ -f "$LIB_PATH" ]; then
                cp "$LIB_PATH" "$WORKDIR/lib/"
                echo -e "${GREEN}  ✓ 复制: $LIB${NC}"
            fi
        fi
    done
    
    # ----- 6. 复制基础系统库 -----
    echo -e "${BLUE}[6/8] 复制基础系统库...${NC}"
    
    # 电视盒子需要的基础库
    BASE_LIBS="
        libc.so
        libm.so
        libdl.so
        libpthread.so
        libresolv.so
        librt.so
        libutil.so
        libstdc++.so
        libgcc_s.so
        libc++_shared.so
        libssl.so
        libcrypto.so
        libz.so
        libbz2.so
        liblzma.so
        libexpat.so
        libsqlite3.so
        libffi.so
        libncursesw.so
        libreadline.so
        libpanelw.so
    "
    
    for LIB in $BASE_LIBS; do
        if [ ! -f "$WORKDIR/lib/$LIB" ]; then
            # 优先查找对应架构的库
            LIB_PATH=""
            if [ -n "$TERMUX_LIB_PATH" ]; then
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
    
    # 复制 libpython 库
    LIBPYTHON=$(find "${TERMUX_PREFIX}/lib" -name "libpython${PYTHON_VER}.so*" 2>/dev/null | head -1)
    if [ -n "$LIBPYTHON" ]; then
        cp "$LIBPYTHON" "$WORKDIR/lib/"
        echo -e "${GREEN}  ✓ 复制: $(basename $LIBPYTHON)${NC}"
    fi
    
    # ----- 7. 创建启动脚本 -----
    echo -e "${BLUE}[7/8] 创建启动脚本...${NC}"
    
    # Python 主启动脚本
    cat > "$WORKDIR/bin/python-tv" << 'EOF'
#!/system/bin/sh
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
export LD_LIBRARY_PATH="$BASE_DIR/lib:/system/lib:/vendor/lib:$LD_LIBRARY_PATH"
export PYTHONHOME="$BASE_DIR"
export PYTHONPATH="$BASE_DIR/lib/python${PYTHON_VER}/site-packages"
exec "$SCRIPT_DIR/python3" "$@"
EOF
    chmod 755 "$WORKDIR/bin/python-tv"
    
    # pip 启动脚本
    if [ -f "$WORKDIR/bin/pip3" ]; then
        cat > "$WORKDIR/bin/pip-tv" << 'EOF'
#!/system/bin/sh
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
export LD_LIBRARY_PATH="$BASE_DIR/lib:/system/lib:/vendor/lib:$LD_LIBRARY_PATH"
export PYTHONHOME="$BASE_DIR"
export PYTHONPATH="$BASE_DIR/lib/python${PYTHON_VER}/site-packages"
exec "$SCRIPT_DIR/python3" -m pip "$@"
EOF
        chmod 755 "$WORKDIR/bin/pip-tv"
    fi
    
    # 创建测试脚本
    cat > "$WORKDIR/test.py" << 'EOF'
import sys
import platform

print("=" * 50)
print("Python 测试脚本")
print("=" * 50)
print(f"Python 版本: {sys.version}")
print(f"Python 可执行文件: {sys.executable}")
print(f"平台信息: {platform.platform()}")
print(f"架构: {platform.machine()}")
print("=" * 50)

print("\n测试基础模块导入:")
modules = ['os', 'sys', 'json', 're', 'math', 'time', 'datetime']
for mod in modules:
    try:
        __import__(mod)
        print(f"  ✓ {mod}")
    except ImportError as e:
        print(f"  ✗ {mod}: {e}")

print("\n测试数学运算:")
print(f"  1 + 2 = {1+2}")
print(f"  3 * 4 = {3*4}")

print("\n✅ 所有测试完成！")
EOF
    
    # 创建架构信息文件
    cat > "$WORKDIR/arch-info.txt" << EOF
打包架构信息:
- 目标架构: ${TARGET_ARCH}
- 打包设备架构: ${CURRENT_ARCH}
- 打包日期: $(date)
- Python 版本: ${PYTHON_FULL}

注意: 如果运行出现问题，请在真实的 ${TARGET_ARCH} 设备上重新打包
EOF
    
    # 创建 README
    cat > "$WORKDIR/README.txt" << EOF
Python ${PYTHON_FULL} for Android TV Box (${TARGET_ARCH})

使用说明:
1. 解压到电视盒子目录 (如 /sdcard/python)
2. 运行测试: cd /sdcard/python && ./bin/python-tv test.py
3. 运行脚本: ./bin/python-tv 你的脚本.py
4. 安装包: ./bin/pip-tv install 包名

环境变量:
- LD_LIBRARY_PATH: lib:/system/lib:/vendor/lib
- PYTHONHOME: 当前目录
- PYTHONPATH: lib/python${PYTHON_VER}/site-packages

打包日期: $(date)
EOF
    
    echo -e "${GREEN}  ✓ 脚本创建完成${NC}"
    
    # ----- 8. 测试打包的 Python -----
    echo -e "${BLUE}[8/8] 测试打包的 Python...${NC}"
    cp -r "$WORKDIR/"* "$TEST_DIR/"
    
    # 设置测试环境
    export TEST_LD_LIBRARY_PATH="$TEST_DIR/lib:/system/lib:/vendor/lib"
    export TEST_PYTHONHOME="$TEST_DIR"
    
    echo -e "${YELLOW}  运行测试脚本...${NC}"
    
    # 尝试运行 Python
    if env -i LD_LIBRARY_PATH="$TEST_LD_LIBRARY_PATH" PYTHONHOME="$TEST_PYTHONHOME" "$TEST_DIR/bin/python3" test.py > "$TEST_DIR/test-output.log" 2>&1; then
        echo -e "${GREEN}  ✓ Python 测试通过${NC}"
        echo -e "${GREEN}  ✓ $(env -i LD_LIBRARY_PATH="$TEST_LD_LIBRARY_PATH" "$TEST_DIR/bin/python3" --version 2>/dev/null)${NC}"
    else
        echo -e "${RED}  ✗ Python 测试失败${NC}"
        echo -e "${YELLOW}  错误信息:${NC}"
        tail -10 "$TEST_DIR/test-output.log"
        
        # 尝试直接运行查看错误
        echo -e "${YELLOW}  尝试直接运行:${NC}"
        env -i LD_LIBRARY_PATH="$TEST_LD_LIBRARY_PATH" "$TEST_DIR/bin/python3" --version 2>&1 || true
        
        echo ""
        echo -e "${YELLOW}  是否继续打包？(y/n)${NC}"
        read -p "> " CONTINUE
        if [[ "$CONTINUE" != "y" && "$CONTINUE" != "Y" ]]; then
            echo -e "${RED}打包取消${NC}"
            rm -rf "$WORKDIR" "$TEST_DIR"
            exit 1
        fi
    fi
    
    # ----- 9. 打包为 ZIP -----
    echo -e "${BLUE}[9/8] 打包为 ZIP...${NC}"
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
    echo -e "  目标架构: ${YELLOW}${TARGET_ARCH}${NC}"
    echo -e "  打包设备: ${YELLOW}${CURRENT_ARCH}${NC}"
    echo -e "${CYAN}================================================${NC}"
    echo ""
    echo -e "${PURPLE}lab.json 配置:${NC}"
    echo '  {'
    echo "    \"name\": \"python\","
    echo "    \"group\": \"runtime\","
    echo "    \"version\": \"${PYTHON_FULL}\","
    echo "    \"binary_path\": \"bin/python-tv\","
    echo "    \"var_path\": {"
    echo "      \"PATH\": \"bin\","
    echo "      \"LD_LIBRARY_PATH\": \"lib:/system/lib:/vendor/lib\","
    echo "      \"PYTHONHOME\": \".\","
    echo "      \"PYTHONPATH\": \"lib/python${PYTHON_VER}/site-packages\""
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
    read -p "是否清理临时文件？(y/n): " CLEANUP
    if [[ "$CLEANUP" == "y" || "$CLEANUP" == "Y" ]]; then
        rm -rf "$WORKDIR" "$TEST_DIR"
        echo -e "${GREEN}✓ 已清理临时文件${NC}"
    else
        echo -e "${YELLOW}临时文件保留在:${NC}"
        echo "  - $WORKDIR"
        echo "  - $TEST_DIR"
    fi
}

# ---------- 主函数 ----------
main() {
    init_vars
    check_storage
    check_environment
    
    echo ""
    echo -e "${YELLOW}是否开始打包？(y/n)${NC}"
    read -p "> " START
    if [[ "$START" == "y" || "$START" == "Y" ]]; then
        start_packaging
    else
        echo -e "${RED}打包取消${NC}"
        exit 0
    fi
}

main "$@"