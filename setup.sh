#!/data/data/com.termux/files/usr/bin/bash
# =====================================================
# Termux 一键环境安装脚本
# 安装 Python + PHP + SQLite + MariaDB + 常用依赖
# 作者: ChatGPT-GPT5
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

echo "🚀 初始化数据库..."
mysql_install_db >/dev/null 2>&1 || true

echo "✅ 检查版本信息..."
echo "Python 版本: $(python -V 2>&1)"
echo "PHP 版本: $(php -v | head -n 1)"
echo "SQLite 版本: $(sqlite3 --version 2>/dev/null || echo '未安装')"

echo "📂 创建示例目录..."
mkdir -p ~/php
mkdir -p ~/python
echo "<?php phpinfo(); ?>" > ~/php/index.php
echo "print('Python 环境正常运行！')" > ~/python/test.py

echo "🧩 示例运行命令:"
echo "  启动 PHP 服务器: php -S 0.0.0.0:8081 -t ~/php"
echo "  启动 Python 服务器: python -m http.server 8082"
echo "  后台运行 PHP: nohup php -S 0.0.0.0:8081 -t ~/php > ~/php.log 2>&1 &"

echo "🎉 安装完成！"
