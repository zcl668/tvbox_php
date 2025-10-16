#!/data/data/com.termux/files/usr/bin/bash
# =========================================
# Termux PHP 智能守护服务器 + 状态页版
# =========================================
# 作者：GPT-5
# 版本：v2.1
# 功能：
#   ✅ 一键安装 PHP 环境
#   ✅ 自动启动 PHP 内建服务器
#   ✅ 崩溃自动重启（守护）
#   ✅ 自动生成网站目录 + 状态页
#   ✅ 自动整合 .bashrc 面板
#   ✅ 命令：startphp / stopphp / phpstatus / phpsite

# ----------- 配置区 -----------
WEB_DIR="/storage/emulated/0/zcl/php"
PORT=8081
PID_FILE="$HOME/.php_server.pid"
GUARD_FILE="$HOME/.php_guard.pid"

# ----------- 颜色 -----------
GREEN="\033[1;32m"; RED="\033[1;31m"; YELLOW="\033[1;33m"; BLUE="\033[1;34m"; NC="\033[0m"

echo -e "${BLUE}🔧 检查 PHP 环境...${NC}"
if ! command -v php >/dev/null 2>&1; then
  pkg update -y && pkg install php -y
fi

# ----------- 网站目录与文件 -----------
echo -e "${BLUE}📂 初始化网站目录...${NC}"
mkdir -p "$WEB_DIR"

if [ ! -f "$WEB_DIR/index.php" ]; then
cat > "$WEB_DIR/index.php" <<'PHP'
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>欢迎使用 PHP 服务器</title>
<style>
body { background:#111; color:#eee; text-align:center; font-family:Arial; padding-top:60px; }
h1 { color:#00e676; }
a { color:#ff9800; text-decoration:none; }
</style>
</head>
<body>
<h1>PHP 服务器运行中 🚀</h1>
<p>点击查看 <a href="/status">状态页面</a></p>
</body>
</html>
PHP
fi

# ----------- 状态页 -----------
cat > "$WEB_DIR/status.php" <<'PHP'
<?php
$uptime = shell_exec('uptime -p');
$phpv = phpversion();
$time = date("Y-m-d H:i:s");
?>
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>服务器状态</title>
<style>
body { background:#0d1117; color:#e6edf3; font-family:Arial; text-align:center; padding-top:60px; }
.card { background:#161b22; border-radius:16px; display:inline-block; padding:30px 50px; box-shadow:0 0 10px #000; }
h1 { color:#58a6ff; }
p { font-size:16px; }
span { color:#00e676; }
</style>
</head>
<body>
<div class="card">
  <h1>🌐 Termux PHP 状态页</h1>
  <p><b>时间：</b><span><?= $time ?></span></p>
  <p><b>运行环境：</b><span><?= php_uname() ?></span></p>
  <p><b>PHP 版本：</b><span><?= $phpv ?></span></p>
  <p><b>系统运行时间：</b><span><?= trim($uptime) ?></span></p>
  <p><b>网站路径：</b><span><?= getcwd() ?></span></p>
  <hr>
  <p><a href="/">返回首页</a></p>
</div>
</body>
</html>
PHP

# ----------- 生成命令脚本 -----------
make_cmd() {
  local name=$1 content=$2
  echo "$content" > "$PREFIX/bin/$name"
  chmod +x "$PREFIX/bin/$name"
}

# 启动命令
make_cmd "startphp" \
'#!/data/data/com.termux/files/usr/bin/bash
WEB_DIR="/storage/emulated/0/zcl/php"
PORT=8081
PID_FILE="$HOME/.php_server.pid"
GUARD_FILE="$HOME/.php_guard.pid"
GREEN="\033[1;32m"; YELLOW="\033[1;33m"; NC="\033[0m"

start_server() {
  php -S 0.0.0.0:$PORT -t "$WEB_DIR" >/dev/null 2>&1 &
  echo $! > "$PID_FILE"
  echo -e "${GREEN}PHP 启动成功：http://127.0.0.1:$PORT${NC}"
}

start_guard() {
  (
    while true; do
      if [ -f "$PID_FILE" ]; then
        if ! kill -0 $(cat "$PID_FILE") 2>/dev/null; then
          echo -e "${YELLOW}检测到 PHP 已崩溃，正在重启...${NC}"
          start_server
        fi
      else
        start_server
      fi
      sleep 10
    done
  ) &
  echo $! > "$GUARD_FILE"
}

if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
  echo -e "${YELLOW}PHP 已运行中 (PID: $(cat $PID_FILE))${NC}"
else
  start_server
  start_guard
fi'

# 停止命令
make_cmd "stopphp" \
'#!/data/data/com.termux/files/usr/bin/bash
PID_FILE="$HOME/.php_server.pid"
GUARD_FILE="$HOME/.php_guard.pid"
YELLOW="\033[1;33m"; GREEN="\033[1;32m"; NC="\033[0m"
if [ -f "$PID_FILE" ]; then
  kill $(cat "$PID_FILE") 2>/dev/null && rm -f "$PID_FILE"
  echo -e "${YELLOW}PHP 已停止${NC}"
else
  echo -e "${YELLOW}PHP 未运行${NC}"
fi
if [ -f "$GUARD_FILE" ]; then
  kill $(cat "$GUARD_FILE") 2>/dev/null && rm -f "$GUARD_FILE"
  echo -e "${GREEN}守护进程已关闭${NC}"
fi'

# 状态命令
make_cmd "phpstatus" \
'#!/data/data/com.termux/files/usr/bin/bash
PID_FILE="$HOME/.php_server.pid"
GREEN="\033[1;32m"; RED="\033[1;31m"; NC="\033[0m"
if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
  echo -e "${GREEN}PHP 正在运行：http://127.0.0.1:8081${NC}"
else
  echo -e "${RED}PHP 未运行${NC}"
fi'

# 打开目录
make_cmd "phpsite" 'termux-open /storage/emulated/0/zcl/php'

# ----------- 自动显示面板 -----------
if ! grep -q "PHP 智能守护服务器面板" ~/.bashrc; then
cat >> ~/.bashrc <<'EOF'

# PHP 智能守护服务器面板
echo -e "\033[1;34m======== PHP 智能守护服务器面板 ========\033[0m"
if [ -f "$HOME/.php_server.pid" ] && kill -0 \$(cat "$HOME/.php_server.pid") 2>/dev/null; then
    echo -e "\033[1;32m状态: 已启动\033[0m (http://127.0.0.1:8081)"
else
    echo -e "\033[1;31m状态: 未启动\033[0m"
fi
echo -e "命令: startphp 启动 | stopphp 停止 | phpstatus 状态 | phpsite 打开目录"
echo -e "\033[1;34m========================================\033[0m"

EOF
fi

# ----------- 完成提示 -----------
echo -e "${GREEN}✅ 部署完成！${NC}"
echo -e "网站目录：${YELLOW}$WEB_DIR${NC}"
echo -e "访问地址：${GREEN}http://127.0.0.1:$PORT${NC}"
echo -e "状态页地址：${BLUE}http://127.0.0.1:$PORT/status${NC}"
echo -e "命令：startphp | stopphp | phpstatus | phpsite"
