#!/data/data/com.termux/files/usr/bin/bash
# =====================================================
# 📦 Termux 通用环境安装脚本 v4
# 功能：
#   ✅ Python Flask 默认端口 8082
#   ✅ PHP 默认端口 8081
#   ✅ 网站目录：/storage/emulated/0/lz/php
#   ✅ Python 项目目录：/storage/emulated/0/lz/python
#   ✅ 一键修复模式 (--fix)
#   ✅ 可禁用自启动 (--no-auto)
# =====================================================

set -e

# 默认目录
PHP_DIR="/storage/emulated/0/lz/php"
PY_DIR="/storage/emulated/0/lz/python"
BASHRC_FILE="$PREFIX/etc/bash.bashrc"

# 参数解析
NO_AUTO=false
if [[ "$1" == "--fix" ]]; then
    MODE="fix"
elif [[ "$1" == "--no-auto" ]]; then
    MODE="noauto"
    NO_AUTO=true
else
    MODE="install"
fi

# =====================================================
# 🧩 修复模式
# =====================================================
if [[ "$MODE" == "fix" ]]; then
    echo "🧩 启动修复模式..."
    echo "🔧 重新安装核心组件..."
    pkg reinstall -y python php mariadb sqlite || true
    python -m ensurepip --upgrade || true
    pip install --no-cache-dir --upgrade requests lxml pyquery beautifulsoup4 pycryptodome flask aiohttp --break-system-packages || true

    echo "🧹 重建 PHP 和 Python 目录..."
    mkdir -p "$PHP_DIR" "$PY_DIR"

    # PHP 默认首页
    cat > "$PHP_DIR/index.php" <<'EOF'
<?php
echo "<h2>✅ Termux PHP Server 正常运行</h2>";
echo "<p>当前时间: " . date('Y-m-d H:i:s') . "</p>";
?>
EOF

    # Python 默认 Flask app
    cat > "$PY_DIR/app.py" <<'EOF'
from flask import Flask
from datetime import datetime
app = Flask(__name__)

@app.route("/")
def index():
    return f"<h2>✅ Termux Python Flask Server 正常运行</h2><p>当前时间: {datetime.now()}</p>"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8082)
EOF

    # PHP 自启动
    if ! grep -q "php -S 0.0.0.0:8081" "$BASHRC_FILE" && [[ "$NO_AUTO" == false ]]; then
        echo -e "\n# ===== PHP 自启动服务 =====" >> "$BASHRC_FILE"
        echo "cd \"$PHP_DIR\" && php -S 0.0.0.0:8081 >/dev/null 2>&1 &" >> "$BASHRC_FILE"
        echo "# ==========================" >> "$BASHRC_FILE"
    fi

    echo "✅ 修复完成！重启 Termux 后 PHP(8081) 与 Python(8082) 将可运行"
    exit 0
fi

# =====================================================
# 🧱 正常安装流程
# =====================================================
echo "🧰 [1/9] 更新系统..."
pkg update -y && pkg upgrade -y

echo "🐍 [2/9] 安装 Python 及依赖..."
pkg install -y python libxml2 libxslt clang openssl-tool

# pip 检查
if ! command -v pip >/dev/null 2>&1; then
    echo "⚙️ pip 不存在，正在修复..."
    python -m ensurepip --upgrade
fi

echo "🔎 当前 pip 版本:"
pip -V || echo "⚠️ pip 未检测到"

# Python 库安装
echo "📦 [3/9] 安装 Python 库..."
for pkg in requests lxml pyquery beautifulsoup4 pycryptodome flask aiohttp; do
    echo "➡️ 安装 $pkg ..."
    pip install --no-cache-dir "$pkg" --break-system-packages || true
done

echo "🐘 [4/9] 安装 PHP 及数据库支持..."
pkg install -y php php-mysql php-sqlite

echo "🗄️ [5/9] 安装数据库支持 (MariaDB + SQLite)..."
pkg install -y mariadb sqlite

echo "🧰 [6/9] 安装常用工具..."
pkg install -y git curl wget nano unzip zip

echo "🚀 [7/9] 初始化 MariaDB 数据目录..."
mysql_install_db >/dev/null 2>&1 || true

# 创建 PHP & Python 项目目录
echo "🌐 [8/9] 创建项目目录..."
termux-setup-storage
mkdir -p "$PHP_DIR" "$PY_DIR"

# PHP 首页
cat > "$PHP_DIR/index.php" <<'EOF'
<?php
echo "<h2>✅ Termux PHP Server 正常运行</h2>";
echo "<p>当前时间: " . date('Y-m-d H:i:s') . "</p>";
?>
EOF

# Python Flask 示例
cat > "$PY_DIR/app.py" <<'EOF'
from flask import Flask
from datetime import datetime
app = Flask(__name__)

@app.route("/")
def index():
    return f"<h2>✅ Termux Python Flask Server 正常运行</h2><p>当前时间: {datetime.now()}</p>"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8082)
EOF

# =====================================================
# ⚙️ 自动启动配置
# =====================================================
if [[ "$NO_AUTO" == false ]]; then
    echo "⚙️ 配置 PHP 自启动 (端口: 8081)..."
    if ! grep -q "php -S 0.0.0.0:8081" "$BASHRC_FILE"; then
        echo -e "\n# ===== PHP 自启动服务 =====" >> "$BASHRC_FILE"
        echo "cd \"$PHP_DIR\" && php -S 0.0.0.0:8081 >/dev/null 2>&1 &" >> "$BASHRC_FILE"
        echo "# ==========================" >> "$BASHRC_FILE"
    fi
    echo "⚙️ Python Flask 示例 app 已创建 (端口 8082)，请手动启动："
    echo "   cd \"$PY_DIR\" && python app.py"
else
    echo "⏸️ 已跳过 PHP 自启动 (--no-auto 模式)"
fi

# =====================================================
# ✅ 完成信息
# =====================================================
echo "------------------------------------------"
echo "✅ 安装完成！"
echo "Python Flask 端口: 8082"
echo "PHP 端口: 8081"
echo "PHP 网站目录: $PHP_DIR"
echo "Python 项目目录: $PY_DIR"
echo "访问 PHP: http://127.0.0.1:8081"
echo "访问 Python: http://127.0.0.1:8082"
echo "🩹 修复命令: bash install_env.sh --fix"
echo "------------------------------------------"
