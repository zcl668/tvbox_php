#!/data/data/com.termux/files/usr/bin/bash
# =====================================================
# Termux 通用环境安装脚本（含 PHP 8081 自启动）
# 适配所有机型：自动跳过 pip 升级警告 + 兼容安卓14+
# 安装：Python + PHP + 数据库 + 常用依赖
# =====================================================

set -e

echo "🧰 [1/8] 更新系统..."
pkg update -y && pkg upgrade -y

echo "🐍 [2/8] 安装 Python 及依赖..."
pkg install -y python libxml2 libxslt clang openssl-tool

# 检查 pip
if ! command -v pip >/dev/null 2>&1; then
    echo "⚙️  pip 不存在，正在修复..."
    python -m ensurepip --upgrade
fi

echo "🔎 检查 pip 版本..."
pip_version=$(pip -V 2>/dev/null || echo "unknown")
echo "✅ 当前 pip: $pip_version"

# 安装 Python 常用库（安全模式）
echo "📦 [3/8] 安装 Python 第三方库..."
for pkg in requests lxml pyquery beautifulsoup4 pycryptodome flask aiohttp; do
    echo "➡️ 安装 $pkg ..."
    pip install --no-cache-dir "$pkg" --break-system-packages || true
done

echo "🐘 [4/8] 安装 PHP 及数据库支持..."
pkg install -y php php-mysql php-sqlite

echo "🗄️ [5/8] 安装 MariaDB + SQLite..."
pkg install -y mariadb sqlite

echo "🧰 [6/8] 安装常用工具..."
pkg install -y git curl wget nano unzip zip

echo "🚀 [7/8] 初始化 MariaDB 数据目录（如果需要）..."
mysql_install_db >/dev/null 2>&1 || true

# 自动配置 PHP 自启动 (端口 8081)
PHP_DIR="/storage/emulated/0/TermuxPHP/wwwroot"
BASHRC_FILE="$PREFIX/etc/bash.bashrc"

echo "🌐 [8/8] 配置 PHP 自启动服务 (端口: 8081)..."
termux-setup-storage
mkdir -p "$PHP_DIR"

# 创建一个简单的首页
cat > "$PHP_DIR/index.php" <<'EOF'
<?php
echo "<h2>✅ Termux PHP Server 正常运行</h2>";
echo "<p>当前时间: " . date('Y-m-d H:i:s') . "</p>";
?>
EOF

# 写入 bash.bashrc 自启动配置（如未配置）
if ! grep -q "php -S 0.0.0.0:8081" "$BASHRC_FILE"; then
    echo -e "\n# ===== PHP 自启动服务 =====" >> "$BASHRC_FILE"
    echo "cd \"$PHP_DIR\" && php -S 0.0.0.0:8081 >/dev/null 2>&1 &" >> "$BASHRC_FILE"
    echo "# ==========================" >> "$BASHRC_FILE"
fi

echo "------------------------------------------"
echo "✅ 安装完成！以下是环境信息："
echo "Python 版本: $(python -V 2>&1)"
echo "pip 版本: $(pip -V 2>&1 | head -n 1)"
echo "PHP 版本: $(php -v | head -n 1)"
echo "SQLite 版本: $(sqlite3 --version 2>/dev/null || echo '未安装')"
echo "------------------------------------------"
echo "🎉 Termux 启动后会自动运行 PHP 服务端口: 8081"
echo "📁 网站根目录: $PHP_DIR"
echo "🌍 在浏览器访问: http://127.0.0.1:8081 或 http://手机IP:8081"
echo "📌 若要手动重启 PHP，可执行："
echo "     cd \"$PHP_DIR\" && php -S 0.0.0.0:8081"
echo "------------------------------------------"
