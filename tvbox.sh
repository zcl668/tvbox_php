#!/bin/bash
# Termux服务自启脚本（终极修复版 v3.0：进程杀尽 + 端口释放 + 原子更新 + 顶级视觉提示）
# 核心目标：让用户100%清晰知道 yt001 是否启动成功！
termux-wake-lock

# ================================== 🚨 智能更新判断：仅当文件内容变更时才重启 ==================================
YT001_SOURCE="/storage/emulated/0/lz/yt001"
YT001_TARGET="$HOME/bin/yt001"
YT001_LOG="$HOME/yt001_startup.log"
NEED_UPDATE=false

# 获取文件MD5
get_md5() {
    if [ -f "$1" ]; then
        md5sum "$1" 2>/dev/null | awk '{print $1}'
    else
        echo "MISSING"
    fi
}

# ================================== 💀 终极杀进程函数（三重杀 + 端口检测 + fuser兜底） ==================================
kill_all_yt001() {
    local max_attempts=3
    local attempt=1
    local port=1988
    local pids=""

    echo "⏹️ 开始强制终止所有 yt001 进程（最多尝试 $max_attempts 次）..."

    while [ $attempt -le $max_attempts ]; do
        # 获取所有 yt001 进程 PID
        pids=$(pgrep -f "yt001" 2>/dev/null | tr '\n' ' ')
        if [ -z "$pids" ]; then
            echo "✅ 第 $attempt 轮：未发现 yt001 进程"
            break
        fi

        echo "⚠️ 第 $attempt 轮：检测到 yt001 进程 (PID: $pids)，正在终止..."
        
        # 第一轮：优雅终止
        pkill -f "yt001" >/dev/null 2>&1
        sleep 2

        # 第二轮：强制终止
        pkill -9 -f "yt001" >/dev/null 2>&1
        sleep 2

        # 检查端口是否仍被占用
        if command -v netstat >/dev/null 2>&1; then
            if netstat -tlnp 2>/dev/null | grep ":$port " >/dev/null; then
                echo "🚨 第 $attempt 轮：端口 $port 仍被占用，继续强杀..."
            else
                echo "✅ 第 $attempt 轮：端口 $port 已释放"
                break
            fi
        else
            # 无 netstat，退化为只检查进程
            pids_after=$(pgrep -f "yt001" 2>/dev/null | tr '\n' ' ')
            if [ -z "$pids_after" ]; then
                echo "✅ 第 $attempt 轮：进程已清除"
                break
            fi
        fi

        attempt=$((attempt + 1))
    done

    # 👇 终极兜底：如果还有进程或端口占用，用 fuser 强杀（需 psmisc）
    if pgrep -f "yt001" >/dev/null 2>&1 || { command -v netstat >/dev/null && netstat -tlnp 2>/dev/null | grep ":$port " >/dev/null; }; then
        echo "💣 终极兜底：尝试使用 fuser 强制释放端口 $port..."
        if command -v fuser >/dev/null 2>&1; then
            fuser -k $port/tcp 2>/dev/null
            sleep 2
        else
            echo "📦 未安装 fuser (psmisc)，正在静默安装..."
            apt update >/dev/null 2>&1 && apt install -y psmisc >/dev/null 2>&1
            if command -v fuser >/dev/null 2>&1; then
                fuser -k $port/tcp 2>/dev/null
                sleep 2
            else
                echo "❌ fuser 安装失败，跳过端口强制释放"
            fi
        fi
    fi

    # 最终验证
    sleep 1
    if pgrep -f "yt001" >/dev/null 2>&1; then
        echo "❌ 仍有残留进程，终极杀进程失败！"
        return 1
    else
        echo "✅ 所有 yt001 进程已清理"
        return 0
    fi
}

# ================================== 🧨 原子更新 + 强制重启 yt001（核心兜底函数） ==================================
atomic_update_and_restart_yt001() {
    local SOURCE="$1"
    local TARGET="$2"
    local LOG="$3"
    local TEMP_TARGET="${TARGET}.tmp"

    if [ ! -f "$SOURCE" ]; then
        echo "❌ 源文件不存在：$SOURCE，无法更新"
        return 1
    fi

    # 1. 创建目标目录
    mkdir -p "$(dirname "$TARGET")"

    # 2. 原子复制：先写临时文件，再 mv 替换（避免写入中断导致文件损坏）
    if ! cp -f "$SOURCE" "$TEMP_TARGET" 2>/dev/null; then
        echo "❌ 复制到临时文件失败：$TEMP_TARGET"
        return 1
    fi

    chmod 755 "$TEMP_TARGET"
    if [ ! -x "$TEMP_TARGET" ]; then
        echo "❌ 临时文件无执行权限"
        rm -f "$TEMP_TARGET"
        return 1
    fi

    # 3. 彻底杀死所有 yt001 进程（调用终极函数）
    kill_all_yt001
    if [ $? -ne 0 ]; then
        echo "⚠️ 进程清理不完全，仍尝试继续更新..."
    fi

    # 4. 原子替换
    if ! mv -f "$TEMP_TARGET" "$TARGET" 2>/dev/null; then
        echo "❌ 原子替换失败：$TEMP_TARGET -> $TARGET"
        rm -f "$TEMP_TARGET"
        return 1
    fi

    echo "✅ yt001 已原子更新至：$TARGET"

    # 5. 预检查
    if [ ! -f "$TARGET" ]; then
        echo "❌ 目标文件不存在：$TARGET"
        return 1
    fi
    if [ ! -x "$TARGET" ]; then
        chmod 755 "$TARGET"
        if [ ! -x "$TARGET" ]; then
            echo "❌ 仍无执行权限：$TARGET"
            return 1
        fi
    fi

    # 6. 启动前再杀一次（防御性）
    pkill -f "yt001" >/dev/null 2>&1
    sleep 1

    # 7. 启动新进程
    rm -f "$LOG"
    termux-wake-lock
    "$TARGET" > "$LOG" 2>&1 &
    local pid=$!

    sleep 4  # 给足时间启动

    if ps -p "$pid" >/dev/null && pgrep -f "yt001" >/dev/null; then
        echo "🎉 yt001 新版本启动成功！PID: $pid"
        return 0
    else
        echo "❌ yt001 新版本启动失败！查看日志：$LOG"
        tail -n 5 "$LOG" 2>/dev/null
        return 1
    fi
}

# ================================== 基础工具函数 ==================================
color() { echo -e "\033[1;$1m$2\033[0m"; }
print_step() { echo -e "\n$(color 34 "===== $1 =====")"; }
print_ok() { echo "  $(color 32 "✅ $1")"; }
print_warn() { echo "  $(color 33 "⚠️ $1")"; }
print_skip() { echo "  $(color 36 "⏭️ $1")"; }
print_err() { echo "  $(color 31 "❌ $1")"; return 1; }

# 服务状态检查
check_service() {
    local name=$1
    local process=$2
    if pgrep -x "$process" >/dev/null 2>&1; then
        local pids=$(pgrep -x "$process" | tr '\n' ' ')
        echo "  $(color 32 "✅ $name 运行中") (PID: $pids)"
        return 0
    else
        echo "  $(color 31 "❌ $name 未运行") (手动启动：$process)"
        return 1
    fi
}

# 智能判断软件是否已安装
check_package_installed() {
    local pkg=$1
    if dpkg -l | grep -q "^ii  $pkg "; then
        return 0  # 已安装
    else
        return 1  # 未安装
    fi
}

# ================================== 核心：关键文件检查与强制下载 ==================================
check_critical_files_and_download() {
    local WEB_DIR="/storage/emulated/0/lz"
    local critical_files=(
        "$WEB_DIR/aa.json"       # 核心配置文件
        "$WEB_DIR/yt001"         # 执行文件
        "$WEB_DIR/yt.jar"        # 依赖jar包
    )
    local missing_files=()

    for file in "${critical_files[@]}"; do
        if [ ! -f "$file" ] || [ ! -s "$file" ]; then
            missing_files+=("$file")
        fi
    done

    if [ ${#missing_files[@]} -gt 0 ]; then
        echo -e "\n$(color 31 "⚠️ 检测到以下关键文件缺失或损坏：")"
        for file in "${missing_files[@]}"; do
            echo "  - $file"
        done
        
        echo -e "\n$(color 33 "📥 开始强制下载 lz.zip 以修复缺失文件...")"
        echo "$(color 36 "   下载地址：http://139.185.42.4:14888/lz.zip")"
        echo "$(color 36 "   进度格式：[百分比] [已下载/总大小] [速度] [剩余时间]")"
        
        cd "$HOME" || exit 1
        rm -f lz.zip
        
        if wget --progress=bar:force -O lz.zip "http://139.185.42.4:14888/lz.zip"; then
            echo -e "\n$(color 32 "✅ 下载完成，开始解压并覆盖文件...")"
            
            if unzip -o lz.zip >/dev/null 2>&1; then
                mkdir -p "$WEB_DIR"
                cp -rf lz/* "$WEB_DIR"/ 2>/dev/null
                
                # 👇 下载后强制清理残留进程（防止文件占用）
                kill_all_yt001 >/dev/null 2>&1
                
                echo "$(color 32 "📁 所有文件已更新至：$WEB_DIR")"
                rm -rf lz.zip lz/
                print_ok "关键文件修复完成"
                return 0
            else
                print_err "lz.zip 解压失败，无法修复文件"
                rm -f lz.zip
                return 1
            fi
        else
            print_err "lz.zip 下载失败，无法修复缺失文件（请检查网络）"
            rm -f lz.zip
            return 1
        fi
    else
        print_ok "所有关键文件（aa.json、yt001、yt.jar）均存在且完整"
        return 0
    fi
}

# ================================== 核心1：智能IP获取 ==================================
get_smart_ip() {
    local IP=""
    IP=$(getprop dhcp.wlan0.ipaddress 2>/dev/null)
    IP=$(echo "$IP" | tr '_' '.' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' 2>/dev/null)
    if [ -n "$IP" ]; then
        echo "$IP"
        return 0
    fi

    IP=$(getprop dhcp.eth0.ipaddress 2>/dev/null)
    IP=$(echo "$IP" | tr '_' '.' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' 2>/dev/null)
    if [ -n "$IP" ]; then
        echo "$IP"
        return 0
    fi

    if command -v python >/dev/null 2>&1; then
        IP=$(python -c "import socket; s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM); s.connect(('8.8.8.8',80)); print(s.getsockname()[0]); s.close()" 2>/dev/null)
        if [ -n "$IP" ] && echo "$IP" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' >/dev/null; then
            echo "$IP"
            return 0
        fi
    fi

    echo "127.0.0.1"
    return 0
}

get_latest_json_urls() {
    local WEB_DIR=$1
    local IP=$(get_smart_ip)

    local AA_JSON_URL="http://$IP:8080/aa.json"
    local AAA_JSON_URL="http://$IP:8080/aaa.json"
    local AA_EXIST="false"
    local AAA_EXIST="false"
    [ -f "$WEB_DIR/aa.json" ] && AA_EXIST="true"
    [ -f "$WEB_DIR/aaa.json" ] && AAA_EXIST="true"

    echo "$IP $AA_JSON_URL $AAA_JSON_URL $AA_EXIST $AAA_EXIST"
}

# ================================== 核心2：aaa.json自动生成函数 ==================================
generate_aaa_json() {
    local AA_JSON_PATH="$1"
    local AAA_JSON_PATH="$2"
    
    if [ ! -f "$AA_JSON_PATH" ]; then
        print_warn "aa.json不存在，无法生成aaa.json（路径：$AA_JSON_PATH）"
        return 1
    fi
    
    local IP=$(get_smart_ip)
    sed "s/127.0.0.1/$IP/g" "$AA_JSON_PATH" > "$AAA_JSON_PATH"
    
    if [ -f "$AAA_JSON_PATH" ] && [ -s "$AAA_JSON_PATH" ]; then
        print_ok "aaa.json生成成功（IP: $IP）"
        return 0
    else
        print_err "aaa.json生成失败"
        return 1
    fi
}

# ================================== 核心3：启动面板展示 ==================================
show_startup_dashboard() {
    clear
    WEB_DIR="/storage/emulated/0/lz"
    echo -e "$(color 35 "==============================================")"
    echo -e "  📱 Termux 服务状态面板"
    echo -e "$(color 35 "==============================================")"

    local URL_DATA=$(get_latest_json_urls "$WEB_DIR")
    local IP=$(echo "$URL_DATA" | awk '{print $1}')
    local AA_JSON_URL=$(echo "$URL_DATA" | awk '{print $2}')
    local AAA_JSON_URL=$(echo "$URL_DATA" | awk '{print $3}')
    local AA_EXIST=$(echo "$URL_DATA" | awk '{print $4}')
    local AAA_EXIST=$(echo "$URL_DATA" | awk '{print $5}')

    echo -e "\n$(color 36 "📊 服务运行状态:")"
    check_service "Nginx" "nginx"
    check_service "PHP-FPM" "php-fpm"
    
    YT001_BIN_PATH="$HOME/bin/yt001"
    echo -e "\n$(color 36 "🚀 yt001 状态:")"
    if [ -f "$YT001_BIN_PATH" ]; then
        if pgrep -f "$YT001_BIN_PATH" >/dev/null 2>&1; then
            local yt_pids=$(pgrep -f "$YT001_BIN_PATH" | tr '\n' ' ')
            echo "  $(color 32 "✅ 运行中") (PID: $yt_pids)"
        else
            echo "  $(color 31 "❌ 未运行")"
            echo "  📌 手动启动: $YT001_BIN_PATH &"
        fi
    else
        print_warn "yt001 可执行文件不存在（将自动恢复）"
    fi

    echo -e "\n$(color 36 "🌐 局域网访问地址:")"
    if [[ "$IP" != "127.0.0.1" ]]; then
        if [[ "$IP" =~ ^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[0-1])) ]]; then
            echo "  🔹 当前局域网IP: $(color 32 "$IP")"
            echo -e "  📌 aa.json 访问: $(color 32 "$AA_JSON_URL")"
            echo -e "  📌 aaa.json 访问: $(color 32 "$AAA_JSON_URL")"
        else
            echo "  🔹 当前IP: $(color 32 "$IP")"
            echo -e "  📌 aa.json 访问: $(color 32 "$AA_JSON_URL")"
            echo -e "  📌 aaa.json 访问: $(color 32 "$AAA_JSON_URL")"
        fi
    else
        echo "  🔹 当前IP: $(color 33 "$IP")（需同一设备访问）"
        echo -e "  📌 aa.json 访问: $(color 32 "$AA_JSON_URL")"
        echo -e "  📌 aaa.json 访问: $(color 32 "$AAA_JSON_URL")"
    fi

    echo -e "\n$(color 36 "📄 核心文件状态:")"
    echo "  📄 aa.json: $( [ "$AA_EXIST" = "true" ] && echo "$(color 32 "存在")" || echo "$(color 31 "不存在")" )"
    echo "  📄 aaa.json: $( [ "$AAA_EXIST" = "true" ] && echo "$(color 32 "存在")" || echo "$(color 31 "不存在")" )"
    echo "  📄 yt001: $( [ -f "$WEB_DIR/yt001" ] && echo "$(color 32 "存在")" || echo "$(color 31 "不存在")" )"
    echo "  📄 yt.jar: $( [ -f "$WEB_DIR/yt.jar" ] && echo "$(color 32 "存在")" || echo "$(color 31 "不存在")" )"
    echo "  🔹 网站目录: $(color 36 "$WEB_DIR")"

    echo -e "\n$(color 36 "💡 快速操作指南:")"
    echo "  - 重启服务: $(color 33 "pkill nginx; pkill php-fpm; nginx; php-fpm")"
    echo "  - 强制更新文件: $(color 33 "rm -rf /storage/emulated/0/lz && bash ~/.bashrc")"
    echo "  - 测试aa.json: $(color 33 "curl $AA_JSON_URL")"
    echo -e "\n$(color 35 "==============================================")"
}

# ================================== 核心4：二次启动判断 ==================================
is_second_start() {
    BASHRC="$HOME/.bashrc"
    if grep -q "# >>> 自动启动 Nginx 和 PHP-FPM（无tput版）<<<" "$BASHRC" || grep -q "# >>> 自动启动 yt001（带自动更新）<<<" "$BASHRC"; then
        return 0
    else
        return 1
    fi
}

# ================================== 存储权限检查 ==================================
if [ ! -d "$HOME/storage" ]; then
    echo "正在请求存储权限..."
    termux-setup-storage
    sleep 5
    if [ ! -d "$HOME/storage" ]; then
        echo "❌ 未获得存储权限，请手动运行 termux-setup-storage"
        exit 1
    fi
    print_ok "存储权限已获取"
else
    print_skip "存储权限已存在，跳过请求"
fi

# ================================== 判断是否需要更新 ==================================
if [ ! -f "$YT001_SOURCE" ]; then
    echo "⚠️ 源文件不存在：$YT001_SOURCE，跳过更新"
elif [ ! -f "$YT001_TARGET" ]; then
    echo "🆕 目标文件不存在，标记为需要初始化"
    NEED_UPDATE=true
else
    MD5_SOURCE=$(get_md5 "$YT001_SOURCE")
    MD5_TARGET=$(get_md5 "$YT001_TARGET")
    if [ "$MD5_SOURCE" != "$MD5_TARGET" ]; then
        echo "🔄 检测到 yt001 文件内容变更（源MD5: $MD5_SOURCE ≠ 目标MD5: $MD5_TARGET），标记为需要更新"
        NEED_UPDATE=true
    else
        echo "✅ yt001 文件内容一致，无需更新"
    fi
fi

# ================================== 二次启动处理 ====================================
if is_second_start; then
    WEB_DIR="/storage/emulated/0/lz"
    AA_JSON="$WEB_DIR/aa.json"
    AAA_JSON="$WEB_DIR/aaa.json"
    YT001_BIN_PATH="$HOME/bin/yt001"
    
    print_step "关键文件完整性检查"
    check_critical_files_and_download
    
    echo -e "\n$(color 36 "🔄 自动检查并生成aaa.json...")"
    if [ -f "$AA_JSON" ]; then
        generate_aaa_json "$AA_JSON" "$AAA_JSON"
    else
        print_warn "aa.json不存在，无法自动生成aaa.json"
    fi
    
    echo -e "\n$(color 36 "🔄 检查并更新 yt001...")"
    if [ -f "$YT001_SOURCE" ]; then
        if [ "$NEED_UPDATE" = true ]; then
            atomic_update_and_restart_yt001 "$YT001_SOURCE" "$YT001_BIN_PATH" "$YT001_LOG"
        else
            # 👇 静默检查：防止手动替换文件未触发更新
            MD5_SOURCE=$(get_md5 "$YT001_SOURCE")
            MD5_TARGET=$(get_md5 "$YT001_BIN_PATH")
            if [ "$MD5_SOURCE" != "$MD5_TARGET" ]; then
                echo "🔄 静默检测到文件变更，立即热更新..."
                atomic_update_and_restart_yt001 "$YT001_SOURCE" "$YT001_BIN_PATH" "$YT001_LOG"
            else
                # 未更新，但检查是否运行
                if ! pgrep -f "$YT001_BIN_PATH" >/dev/null; then
                    echo "🔄 yt001 未运行，尝试启动..."
                    atomic_update_and_restart_yt001 "$YT001_SOURCE" "$YT001_BIN_PATH" "$YT001_LOG"
                else
                    echo "✅ yt001 已在运行，无需操作"
                fi
            fi
        fi
    else
        print_warn "源文件不存在，无法更新和启动"
    fi
    
    echo -e "\n$(color 36 "🔄 加载服务状态面板...")"
    show_startup_dashboard
    
    echo -e "\n$(color 32 "✅ 所有启动流程已完成")"
    exit 0
fi

# ================================== 首次启动：智能安装 ==================================
print_step "智能安装检测（仅安装未装组件）"

if [ ! -f "$HOME/.termux_first_update_done" ]; then
    echo -e "\n正在执行系统更新（首次启动）..."
    apt update -y && apt upgrade -y && apt autoremove -y && apt autoclean
    touch "$HOME/.termux_first_update_done"
    print_ok "系统更新完成"
else
    echo -e "\n$(print_skip "系统已更新过，跳过")"
fi

REQUIRED_PKGS=("nginx" "php" "php-fpm" "unzip" "wget" "python" "curl" "psmisc")
for pkg in "${REQUIRED_PKGS[@]}"; do
    if check_package_installed "$pkg"; then
        print_skip "$pkg 已安装，跳过"
    else
        echo "📦 正在安装 $pkg..."
        apt install -y "$pkg"
        if check_package_installed "$pkg"; then
            print_ok "$pkg 安装完成"
        else
            print_err "$pkg 安装失败，请手动执行：apt install -y $pkg"
        fi
    fi
done

# ================================== Nginx配置 ==================================
print_step "Nginx 配置检测"

if [ ! -d "$PREFIX/logs" ]; then
    mkdir -p "$PREFIX/logs"
    print_ok "Nginx 日志目录创建完成"
else
    print_skip "Nginx 日志目录已存在，跳过"
fi

if [ ! -f "$PREFIX/etc/nginx/mime.types" ] || [ ! -s "$PREFIX/etc/nginx/mime.types" ]; then
    cat > "$PREFIX/etc/nginx/mime.types" <<'EOF'
types {
    text/html                             html htm shtml;
    text/css                              css;
    text/xml                              xml;
    image/gif                             gif;
    image/jpeg                            jpeg jpg;
    application/javascript                js;
    application/atom+xml                  atom;
    application/rss+xml                   rss;
    application/json                      json;
    image/png                             png;
    image/svg+xml                         svg svgz;
    image/vnd.microsoft.icon              ico;
    application/x-font-ttf                ttf;
    application/x-font-woff               woff;
    font/opentype                         otf;
    application/vnd.ms-fontobject         eot;
    application/octet-stream              bin exe dll;
    application/octet-stream              deb rpm;
    application/octet-stream              iso img;
    audio/midi                            mid midi kar;
    audio/mpeg                            mp3;
    video/mp4                             mp4;
    video/mpeg                            mpeg mpg;
}
EOF
    print_ok "Nginx mime.types 配置完成"
else
    print_skip "Nginx mime.types 已存在且有效，跳过"
fi

NGINX_CONF="$PREFIX/etc/nginx/nginx.conf"
if [ ! -f "$NGINX_CONF" ] || ! grep -q "root /storage/emulated/0/lz;" "$NGINX_CONF"; then
    cat > "$NGINX_CONF" <<'EOF'
# Nginx for Termux
worker_processes 1;
error_log logs/error.log;
events {
    worker_connections 1024;
}
http {
    include mime.types;
    default_type application/octet-stream;
    charset utf-8;
    sendfile on;
    keepalive_timeout 65;
    server {
        listen 8080 default_server;
        server_name localhost;
        charset utf-8;
        root /storage/emulated/0/lz;
        index index.html index.htm index.php;
        location / {
            try_files $uri $uri/ $uri.php?$args;
        }
        error_page 500 502 503 504 /50x.html;
        location = /50x.html {
            root /storage/emulated/0/lz;
        }
        location ~ \.php$ {
            root /storage/emulated/0/lz;
            fastcgi_pass 127.0.0.1:9000;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            include fastcgi_params;
        }
    }
}
EOF
    print_ok "Nginx 主配置完成"
else
    print_skip "Nginx 主配置已存在且有效，跳过"
fi

# ================================== PHP-FPM配置 ==================================
print_step "PHP-FPM 配置检测"

PHP_FPM_CONF="$PREFIX/etc/php-fpm.d/www.conf"
if [ ! -f "$PHP_FPM_CONF" ] || ! grep -q "listen = 127.0.0.1:9000" "$PHP_FPM_CONF"; then
    sed -i 's|listen = /data/data/com.termux/files/usr/var/run/php-fpm.sock|listen = 127.0.0.1:9000|' "$PHP_FPM_CONF"
    print_ok "PHP-FPM 配置已更新为TCP模式"
else
    print_skip "PHP-FPM 配置已为TCP模式，跳过"
fi

# ================================== 网站目录创建 ==================================
print_step "网站目录配置"
WEB_DIR="/storage/emulated/0/lz"
if [ ! -d "$WEB_DIR" ]; then
    mkdir -p "$WEB_DIR"
    print_ok "网站目录创建完成：$WEB_DIR"
else
    print_skip "网站目录已存在：$WEB_DIR"
fi

# ================================== 测试文件创建 ==================================
if [ ! -f "$WEB_DIR/index.php" ]; then
    echo "<?php echo '<h1>PHP 服务器运行中</h1>'; phpinfo(); ?>" > "$WEB_DIR/index.php"
    print_ok "index.php 测试文件已创建"
else
    print_skip "index.php 已存在，跳过"
fi

# ================================== 启动 Nginx ==================================
print_step "启动 Nginx 服务"
pkill -x nginx >/dev/null 2>&1
nginx
sleep 1
if pgrep -x "nginx" > /dev/null; then
    print_ok "Nginx 已启动"
else
    print_err "Nginx 启动失败，请检查日志"
fi

# ================================== 启动 PHP-FPM ==================================
print_step "启动 PHP-FPM 服务"
pkill -x php-fpm >/dev/null 2>&1
php-fpm
sleep 1
if pgrep -x "php-fpm" > /dev/null; then
    print_ok "PHP-FPM 已启动"
else
    print_err "PHP-FPM 启动失败"
fi

# ================================== 配置服务自启动 ===================================
print_step "配置服务自启（含关键文件检查）"
bashrc="$HOME/.bashrc"
marker_nginx="# >>> 自动启动 Nginx 和 PHP-FPM（无tput版）<<<"
sed -i "/# >>> 自动启动 Nginx 和 PHP-FPM/,/# <<< 自动启动 Nginx 和 PHP-FPM/d" "$bashrc"
if ! grep -q "$marker_nginx" "$bashrc"; then
cat >> "$bashrc" <<'EOF'

# >>> 自动启动 Nginx 和 PHP-FPM（无tput版）<<<
# 智能IP获取函数
get_smart_ip() {
    local IP=""
    IP=$(getprop dhcp.wlan0.ipaddress 2>/dev/null)
    IP=$(echo "$IP" | tr '_' '.' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' 2>/dev/null)
    if [ -n "$IP" ]; then
        echo "$IP"
        return 0
    fi

    IP=$(getprop dhcp.eth0.ipaddress 2>/dev/null)
    IP=$(echo "$IP" | tr '_' '.' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' 2>/dev/null)
    if [ -n "$IP" ]; then
        echo "$IP"
        return 0
    fi

    if command -v python >/dev/null 2>&1; then
        IP=$(python -c "import socket; s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM); s.connect(('8.8.8.8',80)); print(s.getsockname()[0]); s.close()" 2>/dev/null)
        if [ -n "$IP" ] && echo "$IP" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' >/dev/null; then
            echo "$IP"
            return 0
        fi
    fi

    if command -v curl >/dev/null 2>&1; then
        IP=$(curl -s --max-time 5 "https://api.ipify.org    " || \
             curl -s --max-time 5 "https://icanhazip.com    " | tr -d '\n' || \
             curl -s --max-time 5 "https://ip.cn/ip    " | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' 2>/dev/null)
        if [ -n "$IP" ]; then
            echo "$IP"
            return 0
        fi
    fi

    echo "127.0.0.1"
    return 0
}

# aaa.json自动生成函数
generate_aaa_json() {
    local AA_JSON_PATH="$1"
    local AAA_JSON_PATH="$2"
    
    if [ ! -f "$AA_JSON_PATH" ]; then
        echo "  ⚠️ aa.json不存在，无法生成aaa.json"
        return 1
    fi
    
    local IP=$(get_smart_ip)
    sed "s/127.0.0.1/$IP/g" "$AA_JSON_PATH" > "$AAA_JSON_PATH"
    
    if [ -f "$AAA_JSON_PATH" ] && [ -s "$AAA_JSON_PATH" ]; then
        echo "  ✅ aaa.json已根据最新IP($IP)生成"
        return 0
    else
        echo "  ❌ aaa.json生成失败"
        return 1
    fi
}

# 启动Nginx
if ! pgrep -x "nginx" > /dev/null 2>&1; then
    nginx >/dev/null 2>&1
    sleep 1
    if pgrep -x "nginx" > /dev/null; then
        echo "✅ Nginx 自启成功"
    else
        echo "❌ Nginx 自启失败，手动启动：nginx"
    fi
else
    echo "✅ Nginx 已在运行"
fi

# 启动PHP-FPM
if ! pgrep -x "php-fpm" > /dev/null 2>&1; then
    php-fpm >/dev/null 2>&1
    sleep 1
    if pgrep -x "php-fpm" > /dev/null; then
        echo "✅ PHP-FPM 自启成功"
    else
        echo "❌ PHP-FPM 自启失败，手动启动：php-fpm"
    fi
else
    echo "✅ PHP-FPM 已在运行"
fi

# 自动生成aaa.json
echo -e "\n🔄 正在自动生成aaa.json..."
WEB_DIR="/storage/emulated/0/lz"
AA_JSON="$WEB_DIR/aa.json"
AAA_JSON="$WEB_DIR/aaa.json"
generate_aaa_json "$AA_JSON" "$AAA_JSON"

# 显示JSON访问地址
IP=$(get_smart_ip)
AA_JSON_URL="http://$IP:8080/aa.json"
AAA_JSON_URL="http://$IP:8080/aaa.json"

echo -e "\n🌐 JSON局域网访问地址:"
echo "  aa.json: $AA_JSON_URL"
echo "  aaa.json: $AAA_JSON_URL"
# <<< 自动启动 Nginx 和 PHP-FPM（无tput版）<<<
EOF
    print_ok "已添加 Nginx/PHP-FPM 自启逻辑"
else
    print_skip "Nginx/PHP-FPM 自启逻辑已存在，跳过"
fi

# ================================== 关键文件初始化检查 ===================================
print_step "关键文件初始化检查（aa.json、yt001、yt.jar）"
check_critical_files_and_download

# ================================== JSON 文件处理 ==================================
print_step "JSON 文件处理"
WEB_DIR="/storage/emulated/0/lz"
AA_JSON="$WEB_DIR/aa.json"
AAA_JSON="$WEB_DIR/aaa.json"

if [ -d "$WEB_DIR" ]; then
    if [ ! -f "$AA_JSON" ]; then
        print_warn "$AA_JSON 不存在（可能下载失败）"
    else
        print_ok "aa.json 存在"
        if [ ! -f "$AAA_JSON" ]; then
            generate_aaa_json "$AA_JSON" "$AAA_JSON"
        fi
    fi
else
    print_warn "网站目录不存在，跳过 aa.json 检查"
fi

# ================================== yt001 部署与启动 ==================================
print_step "yt001 部署与自动更新配置"
YT001_BIN_PATH="$HOME/bin/yt001"

if [ "$NEED_UPDATE" = true ] || [ ! -f "$YT001_BIN_PATH" ]; then
    echo "🔄 检测到需要更新或初始化，执行原子更新+重启..."
    atomic_update_and_restart_yt001 "$YT001_SOURCE" "$YT001_BIN_PATH" "$YT001_LOG"
else
    if [ -f "$YT001_BIN_PATH" ]; then
        if ! pgrep -f "$YT001_BIN_PATH" >/dev/null; then
            echo "🔄 yt001 未运行，尝试启动..."
            atomic_update_and_restart_yt001 "$YT001_SOURCE" "$YT001_BIN_PATH" "$YT001_LOG"
        else
            echo "✅ yt001 已在运行"
        fi
    else
        print_err "yt001 可执行文件不存在，无法启动"
    fi
fi

# ================================== yt001 自启配置（带顶级视觉提示） ===================================
marker_yt001="# >>> 自动启动 yt001（带自动更新 + 顶级视觉提示）<<<"
sed -i "/# >>> 自动启动 yt001/,/# <<< 自动启动 yt001/d" "$bashrc"
if ! grep -q "$marker_yt001" "$bashrc"; then
cat >> "$bashrc" <<'EOF'

# >>> 自动启动 yt001（带自动更新 + 顶级视觉提示）<<<
YT001_SOURCE="/storage/emulated/0/lz/yt001"
YT001_BIN="$HOME/bin/yt001"
YT001_LOG="$HOME/yt001_startup.log"

# 获取MD5
get_md5() {
    if [ -f "$1" ]; then
        md5sum "$1" 2>/dev/null | awk '{print $1}'
    else
        echo "MISSING"
    fi
}

# ================================== 💀 终极杀进程函数 ==================================
kill_all_yt001() {
    local max_attempts=3
    local attempt=1
    local port=1988
    local pids=""

    while [ $attempt -le $max_attempts ]; do
        pids=$(pgrep -f "yt001" 2>/dev/null | tr '\n' ' ')
        if [ -z "$pids" ]; then
            break
        fi

        pkill -f "yt001" >/dev/null 2>&1
        sleep 2
        pkill -9 -f "yt001" >/dev/null 2>&1
        sleep 2

        if command -v netstat >/dev/null 2>&1; then
            if ! netstat -tlnp 2>/dev/null | grep ":$port " >/dev/null; then
                break
            fi
        else
            if [ -z "$(pgrep -f "yt001" 2>/dev/null)" ]; then
                break
            fi
        fi

        attempt=$((attempt + 1))
    done

    if pgrep -f "yt001" >/dev/null 2>&1 || { command -v netstat >/dev/null && netstat -tlnp 2>/dev/null | grep ":$port " >/dev/null; }; then
        if command -v fuser >/dev/null 2>&1; then
            fuser -k $port/tcp 2>/dev/null
            sleep 2
        fi
    fi
}

# ================================== 🧨 原子更新 + 强制重启 yt001 ==================================
atomic_update_and_restart_yt001() {
    local SOURCE="$1"
    local TARGET="$2"
    local LOG="$3"
    local TEMP_TARGET="${TARGET}.tmp"

    if [ ! -f "$SOURCE" ]; then return 1; fi
    mkdir -p "$(dirname "$TARGET")"
    if ! cp -f "$SOURCE" "$TEMP_TARGET" 2>/dev/null; then return 1; fi
    chmod 755 "$TEMP_TARGET"
    if [ ! -x "$TEMP_TARGET" ]; then rm -f "$TEMP_TARGET"; return 1; fi

    kill_all_yt001
    if ! mv -f "$TEMP_TARGET" "$TARGET" 2>/dev/null; then rm -f "$TEMP_TARGET"; return 1; fi

    if [ ! -x "$TARGET" ]; then chmod 755 "$TARGET"; fi
    pkill -f "yt001" >/dev/null 2>&1
    sleep 1

    rm -f "$LOG"
    termux-wake-lock
    "$TARGET" > "$LOG" 2>&1 &
    local pid=$!
    sleep 4

    if ps -p "$pid" >/dev/null && pgrep -f "yt001" >/dev/null; then
        echo "$pid"
        return 0
    else
        return 1
    fi
}

# 🎨 颜色和图标定义
GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
RESET='\033[0m'
BOLD='\033[1m'

# 📢 顶级视觉横幅函数
show_visual_banner() {
    local title="$1"
    local msg="$2"
    local color="$3"
    local icon="$4"

    echo ""
    echo -e "${BLUE}==========================================${RESET}"
    echo -e "${BOLD}${color}${icon} ${title}${RESET}"
    echo -e "${BLUE}==========================================${RESET}"
    if [ -n "$msg" ]; then
        echo -e "$msg"
    fi
    echo -e "${BLUE}==========================================${RESET}"
    echo ""
}

# 🚀 自动更新+重启函数（带顶级视觉提示）
update_and_restart_if_needed() {
    if [ ! -f "$YT001_SOURCE" ]; then
        show_visual_banner "yt001 启动失败 ❌" "源文件不存在：$YT001_SOURCE" "$RED" "❌"
        return 1
    fi

    MD5_SOURCE=$(get_md5 "$YT001_SOURCE")
    MD5_TARGET=$(get_md5 "$YT001_BIN")

    if [ "$MD5_SOURCE" != "$MD5_TARGET" ]; then
        show_visual_banner "检测到 yt001 更新 🔄" "正在热替换并重启..." "$YELLOW" "🔄"
        if pid=$(atomic_update_and_restart_yt001 "$YT001_SOURCE" "$YT001_BIN" "$YT001_LOG"); then
            show_visual_banner "yt001 热更新成功 🎉" "新进程 PID: $pid" "$GREEN" "✅"
        else
            local log_tail=$(tail -n 3 "$YT001_LOG" 2>/dev/null | sed 's/^/   /')
            show_visual_banner "yt001 启动失败 ❌" "请检查日志：$YT001_LOG\n$log_tail" "$RED" "❌"
        fi
    else
        if pgrep -f "$YT001_BIN" >/dev/null; then
            local pids=$(pgrep -f "$YT001_BIN" | tr '\n' ' ')
            show_visual_banner "yt001 已在运行 ✅" "PID: $pids" "$GREEN" "✅"
        else
            show_visual_banner "正在启动 yt001 🚀" "请稍候..." "$YELLOW" "🔄"
            if pid=$(atomic_update_and_restart_yt001 "$YT001_SOURCE" "$YT001_BIN" "$YT001_LOG"); then
                show_visual_banner "yt001 启动成功 🎉" "进程 PID: $pid" "$GREEN" "✅"
            else
                local log_tail=$(tail -n 3 "$YT001_LOG" 2>/dev/null | sed 's/^/   /')
                show_visual_banner "yt001 启动失败 ❌" "请检查日志：$YT001_LOG\n$log_tail" "$RED" "❌"
            fi
        fi
    fi
}

# 🕒 延迟3秒后执行（等Termux环境稳定）
{
    sleep 3
    update_and_restart_if_needed
} &

# <<< 自动启动 yt001（带自动更新 + 顶级视觉提示）<<<
EOF
    print_ok "已添加带顶级视觉提示的 yt001 自启逻辑"
else
    print_skip "yt001 自启逻辑已存在，跳过"
fi

# 生效配置
source "$bashrc"

# ================================== 最终结果输出 + 静默热更新检查 ==================================
IP=$(get_smart_ip)
AA_JSON_URL="http://$IP:8080/aa.json"
AAA_JSON_URL="http://$IP:8080/aaa.json"

# 静默热更新检查（防止手动替换未触发）
if [ -f "$YT001_SOURCE" ] && [ -f "$YT001_TARGET" ]; then
    MD5_SOURCE=$(get_md5 "$YT001_SOURCE")
    MD5_TARGET=$(get_md5 "$YT001_TARGET")
    if [ "$MD5_SOURCE" != "$MD5_TARGET" ]; then
        echo -e "\n🔄 静默检测到 yt001 文件变更，立即热更新..."
        atomic_update_and_restart_yt001 "$YT001_SOURCE" "$YT001_TARGET" "$YT001_LOG"
    fi
fi

clear
show_startup_dashboard

echo -e "\n$(color 32 "✅ 所有部署与更新流程已完成")"
echo -e "$(color 33 "📌 提示：每次打开 Termux，顶部都会显示 yt001 启动状态！")"
echo -e "$(color 33 "📌 修改 /storage/emulated/0/lz/yt001 后，等待3秒自动热更新！")"
