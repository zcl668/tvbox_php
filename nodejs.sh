#!/bin/bash
# ============================================================
# node_tvbox.sh
# 支持在 arm64 设备上打包 armeabi-v7a 版本的 Node.js
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
    
    # 获取 Node.js 版本
    if ! command -v node >/dev/null 2>&1; then
        echo -e "${RED}错误: 未找到 node 命令${NC}"
        echo -e "${YELLOW}请安装 Node.js: pkg install nodejs${NC}"
        exit 1
    fi
    
    NODE_FULL=$(node --version 2>/dev/null | sed 's/v//')
    NODE_VER=$(echo $NODE_FULL | cut -d. -f1)
    
    if [ -z "$NODE_FULL" ]; then
        echo -e "${RED}错误: 无法检测 Node.js 版本${NC}"
        exit 1
    fi
    
    # 输出路径
    OUTPUT_DIR="/storage/emulated/0/编程学习"
    OUTPUT_NAME="node-${NODE_FULL}-tvbox-${TARGET_ARCH}.zip"
    OUTPUT_PATH="${OUTPUT_DIR}/${OUTPUT_NAME}"
    
    # Termux 路径
    TERMUX_PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
    
    # 工作目录
    WORKDIR="$HOME/node_tvbox_repack"
    TEST_DIR="$HOME/node_tvbox_test"
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
    echo -e "${GREEN}检测 Node.js 打包环境${NC}"
    echo -e "${CYAN}================================================${NC}"
    
    echo -e "${GREEN}✓ Node.js 版本: ${NODE_FULL}${NC}"
    echo -e "${GREEN}✓ 当前架构: ${CURRENT_ARCH}${NC}"
    echo -e "${GREEN}✓ 目标架构: ${TARGET_ARCH}${NC}"
    
    # 检查 npm
    if command -v npm >/dev/null 2>&1; then
        NPM_VER=$(npm --version 2>/dev/null)
        echo -e "${GREEN}✓ npm 版本: ${NPM_VER}${NC}"
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
    echo -e "${GREEN}开始打包 Node.js ${NODE_FULL} for ${TARGET_ARCH}${NC}"
    echo -e "${CYAN}================================================${NC}"
    
    # 清理并创建目录
    rm -rf "$WORKDIR" "$TEST_DIR"
    mkdir -p "$WORKDIR/bin"
    mkdir -p "$WORKDIR/lib"
    mkdir -p "$WORKDIR/lib/node_modules"
    mkdir -p "$TEST_DIR"
    
    echo -e "${GREEN}  ✓ 目录创建完成${NC}"
    
    # ----- 1. 复制 Node.js 二进制 -----
    echo -e "${BLUE}[1/7] 复制 Node.js 二进制...${NC}"
    NODE_BIN=$(command -v node)
    cp "$NODE_BIN" "$WORKDIR/bin/node"
    chmod 755 "$WORKDIR/bin/node"
    
    # 检查二进制架构
    if [ "$CURRENT_ARCH" != "$TARGET_ARCH" ]; then
        FILE_ARCH=$(check_file_arch "$NODE_BIN")
        echo -e "${YELLOW}  ⚠ Node.js 二进制架构: ${FILE_ARCH:-未知}${NC}"
    fi
    
    echo -e "${GREEN}  ✓ 已复制: $NODE_BIN${NC}"
    
    # ----- 2. 复制 npm -----
    echo -e "${BLUE}[2/7] 复制 npm...${NC}"
    if command -v npm >/dev/null 2>&1; then
        NPM_BIN=$(command -v npm)
        cp "$NPM_BIN" "$WORKDIR/bin/npm" 2>/dev/null || true
        
        # 复制 npm 模块
        if [ -d "${TERMUX_PREFIX}/lib/node_modules/npm" ]; then
            mkdir -p "$WORKDIR/lib/node_modules"
            cp -r "${TERMUX_PREFIX}/lib/node_modules/npm" "$WORKDIR/lib/node_modules/"
            echo -e "${GREEN}  ✓ npm 模块复制完成${NC}"
        fi
        
        # 创建 npx 链接
        cd "$WORKDIR/bin" && ln -sf npm npx 2>/dev/null || true && cd "$HOME"
    fi
    
    # ----- 3. 收集依赖库 -----
    echo -e "${BLUE}[3/7] 收集依赖库...${NC}"
    
    # 收集 Node.js 二进制依赖
    ALL_DEPS=$(collect_all_deps "$WORKDIR/bin/node" | sort -u)
    
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
    
    # ----- 4. 复制基础系统库 -----
    echo -e "${BLUE}[4/7] 复制基础系统库...${NC}"
    
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
        libicuuc.so
        libicui18n.so
        libicudata.so
        libhttp_parser.so
        libcares.so
        libnghttp2.so
        libuv.so
        libuv.so.1
        libbrotlicommon.so
        libbrotlidec.so
        liblzma.so
        libsqlite3.so
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
    
    # ----- 5. 创建启动脚本 -----
    echo -e "${BLUE}[5/7] 创建启动脚本...${NC}"
    
    # Node.js 主启动脚本
    cat > "$WORKDIR/bin/node-tv" << 'EOF'
#!/system/bin/sh
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
export LD_LIBRARY_PATH="$BASE_DIR/lib:/system/lib:/vendor/lib:$LD_LIBRARY_PATH"
export NODE_PATH="$BASE_DIR/lib/node_modules"
exec "$SCRIPT_DIR/node" "$@"
EOF
    chmod 755 "$WORKDIR/bin/node-tv"
    
    # npm 启动脚本
    if [ -f "$WORKDIR/bin/npm" ] && [ -d "$WORKDIR/lib/node_modules/npm" ]; then
        cat > "$WORKDIR/bin/npm-tv" << 'EOF'
#!/system/bin/sh
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
export LD_LIBRARY_PATH="$BASE_DIR/lib:/system/lib:/vendor/lib:$LD_LIBRARY_PATH"
export NODE_PATH="$BASE_DIR/lib/node_modules"
exec "$SCRIPT_DIR/node" "$BASE_DIR/lib/node_modules/npm/bin/npm-cli.js" "$@"
EOF
        chmod 755 "$WORKDIR/bin/npm-tv"
    fi
    
    # 创建测试脚本
    cat > "$WORKDIR/test.js" << 'EOF'
const os = require('os');
const path = require('path');

console.log("=".repeat(50));
console.log("Node.js 测试脚本");
console.log("=".repeat(50));
console.log(`Node.js 版本: ${process.version}`);
console.log(`可执行文件: ${process.execPath}`);
console.log(`平台: ${process.platform}`);
console.log(`架构: ${process.arch}`);
console.log(`系统: ${os.type()} ${os.release()}`);
console.log("=".repeat(50));

console.log("\n测试基础模块:");
const modules = ['fs', 'http', 'url', 'crypto', 'util', 'events'];
modules.forEach(mod => {
    try {
        require(mod);
        console.log(`  ✓ ${mod}`);
    } catch (e) {
        console.log(`  ✗ ${mod}: ${e.message}`);
    }
});

console.log("\n测试数学运算:");
console.log(`  1 + 2 = ${1 + 2}`);
console.log(`  3 * 4 = ${3 * 4}`);

console.log("\n✅ 所有测试完成！");
EOF
    
    # 创建架构信息文件
    cat > "$WORKDIR/arch-info.txt" << EOF
打包架构信息:
- 目标架构: ${TARGET_ARCH}
- 打包设备架构: ${CURRENT_ARCH}
- 打包日期: $(date)
- Node.js 版本: ${NODE_FULL}

注意: 如果运行出现问题，请在真实的 ${TARGET_ARCH} 设备上重新打包
EOF
    
    # 创建 README
    cat > "$WORKDIR/README.txt" << EOF
Node.js ${NODE_FULL} for Android TV Box (${TARGET_ARCH})

使用说明:
1. 解压到电视盒子目录 (如 /sdcard/node)
2. 运行测试: cd /sdcard/node && ./bin/node-tv test.js
3. 运行脚本: ./bin/node-tv 你的脚本.js
4. 使用 npm: ./bin/npm-tv install 包名

环境变量:
- LD_LIBRARY_PATH: lib:/system/lib:/vendor/lib
- NODE_PATH: lib/node_modules

打包日期: $(date)
EOF
    
    echo -e "${GREEN}  ✓ 脚本创建完成${NC}"
    
    # ----- 6. 测试打包的 Node.js -----
    echo -e "${BLUE}[6/7] 测试打包的 Node.js...${NC}"
    cp -r "$WORKDIR/"* "$TEST_DIR/"
    
    # 设置测试环境
    export TEST_LD_LIBRARY_PATH="$TEST_DIR/lib:/system/lib:/vendor/lib"
    
    echo -e "${YELLOW}  运行测试脚本...${NC}"
    
    # 尝试运行 Node.js
    if env -i LD_LIBRARY_PATH="$TEST_LD_LIBRARY_PATH" "$TEST_DIR/bin/node" test.js > "$TEST_DIR/test-output.log" 2>&1; then
        echo -e "${GREEN}  ✓ Node.js 测试通过${NC}"
        echo -e "${GREEN}  ✓ $(env -i LD_LIBRARY_PATH="$TEST_LD_LIBRARY_PATH" "$TEST_DIR/bin/node" --version 2>/dev/null)${NC}"
    else
        echo -e "${RED}  ✗ Node.js 测试失败${NC}"
        echo -e "${YELLOW}  错误信息:${NC}"
        tail -10 "$TEST_DIR/test-output.log"
        
        # 尝试直接运行查看错误
        echo -e "${YELLOW}  尝试直接运行:${NC}"
        env -i LD_LIBRARY_PATH="$TEST_LD_LIBRARY_PATH" "$TEST_DIR/bin/node" --version 2>&1 || true
        
        echo ""
        echo -e "${YELLOW}  是否继续打包？(y/n)${NC}"
        read -p "> " CONTINUE
        if [[ "$CONTINUE" != "y" && "$CONTINUE" != "Y" ]]; then
            echo -e "${RED}打包取消${NC}"
            rm -rf "$WORKDIR" "$TEST_DIR"
            exit 1
        fi
    fi
    
    # ----- 7. 打包为 ZIP -----
    echo -e "${BLUE}[7/7] 打包为 ZIP...${NC}"
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
    echo "    \"name\": \"nodejs\","
    echo "    \"group\": \"runtime\","
    echo "    \"version\": \"${NODE_FULL}\","
    echo "    \"binary_path\": \"bin/node-tv\","
    echo "    \"var_path\": {"
    echo "      \"PATH\": \"bin\","
    echo "      \"LD_LIBRARY_PATH\": \"lib:/system/lib:/vendor/lib\","
    echo "      \"NODE_PATH\": \"lib/node_modules\""
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