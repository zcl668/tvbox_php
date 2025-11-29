#!/data/data/com.termux/files/usr/bin/bash
# =====================================================
# Termux 环境安装脚本（只安装 Python + PHP + 数据库 + 依赖）
# 不启动任何服务
# =====================================================

echo "🧰 更新系统..."
pkg update -y && pkg upgrade -y

echo "🐍 安装 Python 及核心依赖..."
pkg install python -y
pkg install libxml2 libxslt -y
pip install --upgrade pip
pip install requests lxml pyquery beautifulsoup4 pycryptodome flask aiohttp

echo "🐘 安装 PHP 及数据库支持..."
pkg install php php-mysql php-sqlite -y

echo "🗄️ 安装数据库支持 (MariaDB / SQLite)..."
pkg install mariadb -y

echo "🔧 安装常用工具..."
pkg install git curl wget nano unzip zip clang openssl-tool -y

echo "🚀 初始化 MariaDB 数据库目录（如果需要）..."
mysql_install_db >/dev/null 2>&1 || true

echo "✅ 检查版本信息..."
echo "Python 版本: $(python -V 2>&1)"
echo "PHP 版本: $(php -v | head -n 1)"
echo "SQLite 版本: $(sqlite3 --version 2>/dev/null || echo '未安装')"

echo "🎉 安装完成！"
echo "📌 说明：此脚本只安装环境，不启动 PHP/Python 服务"   把代码需要的依赖都替换国内常用的源
