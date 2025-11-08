#!/data/data/com.termux/files/usr/bin/bash
# =====================================================
# Termux 全能环境安装脚本（适配系统限制版）
# 核心优化：取消pip强制升级，避免Termux包依赖冲突
# 安装范围：Python+核心库 + PHP+SQLite扩展 + 常用开发工具
# =====================================================

# 颜色输出（区分状态）
GREEN="\033[32m[成功]\033[0m"
YELLOW="\033[33m[跳过]\033[0m"
BLUE="\033[34m[执行]\033[0m"
RED="\033[31m[错误]\033[0m"
INFO="\033[96m[说明]\033[0m"

# 核心函数：检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 核心函数：强制校验Python库是否可用
check_python_lib() {
    python -c "import $1" >/dev/null 2>&1
}

# 核心函数：强制校验PHP扩展是否启用
check_php_ext() {
    php -m | grep -q "^$1$" >/dev/null 2>&1
}

# =====================================================
# 步骤1：系统更新（仅首次执行）
# =====================================================
echo -e "\n${BLUE} 1/6 开始系统更新（仅首次运行，更新后永久跳过）"
UPDATE_MARKER="$HOME/.termux_env_system_updated"
if [ ! -f "$UPDATE_MARKER" ]; then
    echo -e "${INFO} 正在更新Termux软件源并升级已安装包..."
    if pkg update -y && pkg upgrade -y; then
        touch "$UPDATE_MARKER"
        echo -e "${GREEN} 系统更新完成，已创建标记文件"
    else
        echo -e "${RED} 系统更新失败！请检查网络后重试"
        exit 1
    fi
else
    echo -e "${YELLOW} 系统已更新过，直接跳过此步骤"
fi

# =====================================================
# 步骤2：安装基础依赖库
# =====================================================
echo -e "\n${BLUE} 2/6 安装基础依赖库（Python/PHP解析/加密必需）"
BASE_DEPS="libxml2 libxslt openssl-tool"
for dep in $BASE_DEPS; do
    if pkg list-installed "$dep" >/dev/null 2>&1; then
        echo -e "${YELLOW} $dep：已安装，跳过"
    else
        echo -e "${INFO} 正在安装 $dep..."
        pkg install -y "$dep" || { echo -e "${RED} $dep 安装失败"; exit 1; }
        echo -e "${GREEN} $dep 安装成功"
    fi
done

# =====================================================
# 步骤3：Python环境安装（适配Termux pip限制）
# =====================================================
echo -e "\n${BLUE} 3/6 安装Python环境（含核心开发库）"
# 校验Python本体
if command_exists python; then
    PY_VERSION=$(python -V 2>&1)
    echo -e "${YELLOW} Python本体：已安装（版本：$PY_VERSION），跳过安装"
else
    echo -e "${INFO} 正在安装Python本体..."
    pkg install -y python || { echo -e "${RED} Python安装失败"; exit 1; }
    echo -e "${GREEN} Python本体安装成功"
fi

# 校验系统pip（取消强制升级，使用Termux自带版本）
if command_exists pip; then
    echo -e "${YELLOW} pip：系统自带版本已存在，无需升级"
else
    echo -e "${INFO} 正在安装系统pip..."
    pkg install -y python-pip || { echo -e "${RED} pip安装失败"; exit 1; }
    echo -e "${GREEN} 系统pip安装成功"
fi

# 安装并强制校验Python核心库
PYTHON_LIBS="requests lxml pyquery beautifulsoup4 pycryptodome flask aiohttp sqlite3"
echo -e "${INFO} 正在检查并安装Python核心库..."
for lib in $PYTHON_LIBS; do
    if check_python_lib "$lib"; then
        echo -e "${YELLOW} Python库 $lib：已安装且可用，跳过"
    else
        echo -e "${INFO} 正在安装 $lib..."
        pip install --no-cache-dir "$lib" || { echo -e "${RED} $lib 安装失败"; exit 1; }
        echo -e "${GREEN} Python库 $lib 安装成功"
    fi
done

# =====================================================
# 步骤4：PHP环境安装
# =====================================================
echo -e "\n${BLUE} 4/6 安装PHP环境（含SQLite扩展）"
# 校验PHP本体
if command_exists php; then
    PHP_VERSION=$(php -v 2>&1 | head -n1)
    echo -e "${YELLOW} PHP本体：已安装（版本：$PHP_VERSION），跳过安装"
else
    echo -e "${INFO} 正在安装PHP本体..."
    pkg install -y php || { echo -e "${RED} PHP安装失败"; exit 1; }
    echo -e "${GREEN} PHP本体安装成功"
fi

# 校验PHP sqlite3扩展
if check_php_ext "sqlite3"; then
    echo -e "${YELLOW} PHP扩展 sqlite3：已安装且启用，跳过"
else
    echo -e "${INFO} 正在安装PHP sqlite3扩展..."
    pkg install -y php-sqlite || { echo -e "${RED} sqlite3扩展安装失败"; exit 1; }
    echo -e "${GREEN} PHP sqlite3扩展安装成功"
fi

# =====================================================
# 步骤5：常用开发工具安装
# =====================================================
echo -e "\n${BLUE} 5/6 安装常用开发工具"
TOOLS="git curl wget nano unzip zip clang"
for tool in $TOOLS; do
    if command_exists "$tool"; then
        echo -e "${YELLOW} 工具 $tool：已安装，跳过"
    else
        echo -e "${INFO} 正在安装 $tool..."
        pkg install -y "$tool" && echo -e "${GREEN} 工具 $tool 安装成功" || echo -e "${YELLOW} 工具 $tool 安装失败（不影响核心环境）"
    fi
done

# =====================================================
# 步骤6：最终完整性校验
# =====================================================
echo -e "\n${BLUE} 6/6 最终完整性校验"
# 校验Python
PY_FINAL_VERSION=$(python -V 2>&1)
if echo "$PY_FINAL_VERSION" | grep -q "Python" && check_python_lib "flask" && check_python_lib "sqlite3"; then
    echo -e "${GREEN} Python环境：可用（版本：$PY_FINAL_VERSION）"
else
    echo -e "${RED} Python环境校验失败"
    exit 1
fi

# 校验PHP
PHP_FINAL_VERSION=$(php -v 2>&1 | head -n1)
if echo "$PHP_FINAL_VERSION" | grep -q "PHP" && check_php_ext "sqlite3"; then
    echo -e "${GREEN} PHP环境：可用（版本：$PHP_FINAL_VERSION，sqlite3扩展已启用）"
else
    echo -e "${RED} PHP环境校验失败"
    exit 1
fi

# 校验SQLite
SQLITE_FINAL_VERSION=$(sqlite3 --version 2>&1 | head -n1)
TEST_DB="termux_env_test.db"
if echo "$SQLITE_FINAL_VERSION" | grep -q "3." && sqlite3 "$TEST_DB" "CREATE TABLE test (id INT); INSERT INTO test VALUES (1); DROP TABLE test;" >/dev/null 2>&1; then
    rm -f "$TEST_DB"
    echo -e "${GREEN} SQLite环境：可用（版本：$SQLITE_FINAL_VERSION）"
else
    rm -f "$TEST_DB"
    echo -e "${RED} SQLite环境校验失败"
    exit 1
fi

# =====================================================
# 安装完成
# =====================================================
echo -e "\n====================================================="
echo -e "${GREEN}🎉 环境安装完成！所有核心组件均已校验可用"
echo -e "====================================================="
echo -e "${INFO} 📌 核心功能命令："
echo -e "   1. Flask服务：flask run --host=0.0.0.0"
echo -e "   2. PHP服务器：php -S 0.0.0.0:8000"
echo -e "   3. SQLite操作：sqlite3 数据库名.db"
echo -e "${INFO} ⚠️  说明：仅安装环境，未启动后台服务"
echo -e "====================================================="
