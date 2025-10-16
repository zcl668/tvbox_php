#!/bin/bash
# ==================================
# tvbox_php 完整菜单恢复脚本
# ==================================

WEB_DIR="/storage/emulated/0/zcl"
BASHRC="$PREFIX/etc/bash.bashrc"
PORT=8081

ok() { echo -e "✅ $1"; }
err() { echo -e "❌ $1"; }
skip() { echo -e "⏭️ $1"; }
step() { echo -e "\n🧩 $1"; }

# 恢复菜单管理功能
menu() {
    while true; do
        echo -e "\n========= tvbox_php 服务控制菜单 ========="
        echo "1) 启动 Nginx + PHP-FPM"
        echo "2) 停止 Nginx + PHP-FPM"
        echo "3) 查看状态"
        echo "4) 打开浏览器"
        echo "5) 重启服务"
        echo "6) 查看日志"
        echo "7) 退出菜单"
        echo "8) 关闭 Termux 后台"
        echo "===================================="
        read -p "请输入选项 [1-8]: " choice

        case "$choice" in
            1)
                start_services
                ok "服务已启动: http://127.0.0.1:$PORT"
                ;;
            2)
                stop_services
                echo "🛑 服务已停止"
                ;;
            3)
                show_status
                ;;
            4)
                termux-open "http://127.0.0.1:$PORT"
                ;;
            5)
                restart_services
                ok "服务已重启: http://127.0.0.1:$PORT"
                ;;
            6)
                show_logs
                ;;
            7)
                echo "退出菜单"
                break
                ;;
            8)
                echo "关闭后台进程 & 退出 Termux"
                stop_services
                pkill -f "com.termux" >/dev/null 2>&1
                pkill -f "termux" >/dev/null 2>&1
                exit 0
                ;;
            *)
                echo "无效输入，请输入 1-8"
                ;;
        esac
    done
}

# 启动服务函数
start_services() {
    stop_services
    sleep 2
    
    # 尝试启动 PHP-FPM
    if ! pgrep -f "php-fpm" >/dev/null; then
        php-fpm --fpm-config "$PREFIX/etc/php-fpm.conf" -c "$PREFIX/etc/php.ini" >/dev/null 2>&1 &
        sleep 3
    fi
    
    # 启动 Nginx
    nginx
    sleep 2
}

# 停止服务函数
stop_services() {
    pkill -f "nginx: master" >/dev/null 2>&1
    pkill -f "php-fpm" >/dev/null 2>&1
    pkill -f "php-fpm: master" >/dev/null 2>&1
    sleep 2
}

# 重启服务函数
restart_services() {
    stop_services
    start_services
}

# 显示状态函数
show_status() {
    echo -e "\n--- 当前服务状态 ---"
    
    # Nginx 状态
    if pgrep -f "nginx: master" >/dev/null; then
        NGINX_PID=$(pgrep -f "nginx: master")
        echo "✅ Nginx 正在运行 (PID: $NGINX_PID)"
        
        # 检查工作进程
        NGINX_WORKERS=$(pgrep -f "nginx: worker" | wc -l)
        echo "   🟢 工作进程: $NGINX_WORKERS 个"
    else
        echo "❌ Nginx 未运行"
    fi
    
    # PHP-FPM 状态
    if pgrep -f "php-fpm" >/dev/null; then
        PHP_MASTER=$(pgrep -f "php-fpm: master")
        PHP_POOLS=$(pgrep -f "php-fpm: pool" | wc -l)
        echo "✅ PHP-FPM 正在运行 (主进程PID: $PHP_MASTER)"
        echo "   🟢 池进程: $PHP_POOLS 个"
    else
        echo "❌ PHP-FPM 未运行"
    fi
    
    # 端口检查
    echo -e "\n--- 端口监听状态 ---"
    if netstat -tulpn 2>/dev/null | grep :$PORT >/dev/null; then
        echo "✅ 端口 $PORT 正在监听 (Nginx)"
    else
        echo "❌ 端口 $PORT 未监听"
    fi
    
    if netstat -tulpn 2>/dev/null | grep :9000 >/dev/null; then
        echo "✅ 端口 9000 正在监听 (PHP-FPM)"
    else
        echo "❌ 端口 9000 未监听"
    fi
    
    # 服务测试
    echo -e "\n--- 服务可用性测试 ---"
    if curl -s http://127.0.0.1:$PORT/index.html >/dev/null; then
        echo "✅ HTML 服务正常"
    else
        echo "❌ HTML 服务异常"
    fi
    
    if curl -s http://127.0.0.1:$PORT/index.php >/dev/null; then
        echo "✅ PHP 服务正常"
    else
        echo "❌ PHP 服务异常"
    fi
    
    # 显示访问地址
    echo -e "\n📍 访问地址: http://127.0.0.1:$PORT"
    echo "📁 网站目录: $WEB_DIR"
}

# 显示日志函数
show_logs() {
    while true; do
        echo -e "\n--- 日志查看菜单 ---"
        echo "1) 查看 Nginx 错误日志"
        echo "2) 查看 Nginx 访问日志"
        echo "3) 查看 PHP-FPM 日志"
        echo "4) 实时查看 Nginx 错误日志"
        echo "5) 返回主菜单"
        read -p "请选择 [1-5]: " log_choice
        
        case "$log_choice" in
            1)
                echo -e "\n📋 Nginx 错误日志 (最后20行):"
                tail -20 "$PREFIX/var/log/nginx/error.log" 2>/dev/null || echo "日志文件不存在"
                ;;
            2)
                echo -e "\n📋 Nginx 访问日志 (最后20行):"
                tail -20 "$PREFIX/var/log/nginx/access.log" 2>/dev/null || echo "日志文件不存在"
                ;;
            3)
                echo -e "\n📋 PHP-FPM 日志 (最后20行):"
                if [ -f "$PREFIX/var/log/php-fpm.log" ]; then
                    tail -20 "$PREFIX/var/log/php-fpm.log"
                elif [ -f "$PREFIX/var/log/php-fpm-www.log" ]; then
                    tail -20 "$PREFIX/var/log/php-fpm-www.log"
                else
                    echo "PHP-FPM 日志文件不存在"
                fi
                ;;
            4)
                echo -e "\n🔍 开始实时监控 Nginx 错误日志 (Ctrl+C 退出)..."
                tail -f "$PREFIX/var/log/nginx/error.log" 2>/dev/null || echo "日志文件不存在"
                ;;
            5)
                break
                ;;
            *)
                echo "无效输入"
                ;;
        esac
    done
}

# 快捷命令设置
setup_aliases() {
    step "设置快捷命令"
    
    if ! grep -q "tvbox-start" "$BASHRC"; then
        cat >> "$BASHRC" <<EOF

# tvbox_php 服务快捷命令
alias tvbox-start='pkill -f "nginx: master" >/dev/null 2>&1; pkill -f php-fpm >/dev/null 2>&1; nginx && php-fpm --fpm-config \$PREFIX/etc/php-fpm.conf -c \$PREFIX/etc/php.ini >/dev/null 2>&1 && echo "✅ tvbox_php 服务已启动: http://127.0.0.1:$PORT"'
alias tvbox-stop='pkill -f "nginx: master" >/dev/null 2>&1; pkill -f php-fpm >/dev/null 2>&1; echo "🛑 tvbox_php 服务已停止"'
alias tvbox-status='pgrep -f "nginx: master" >/dev/null && echo "✅ Nginx 运行中" || echo "❌ Nginx 未运行"; pgrep -f "php-fpm" >/dev/null && echo "✅ PHP-FPM 运行中" || echo "❌ PHP-FPM 未运行"'
alias tvbox-restart='tvbox-stop; sleep 2; tvbox-start'
alias tvbox-logs='tail -f \$PREFIX/var/log/nginx/error.log'
alias tvbox-menu='bash \$HOME/tvbox_menu.sh'

EOF
        ok "快捷命令已添加到 bashrc"
    else
        skip "快捷命令已存在"
    fi
}

# 创建独立的菜单脚本
create_menu_script() {
    step "创建独立菜单脚本"
    
    cat > "$HOME/tvbox_menu.sh" <<'EOF'
#!/bin/bash
# ==================================
# tvbox_php 独立菜单脚本
# 保存为 $HOME/tvbox_menu.sh
# 可以随时运行 bash tvbox_menu.sh 打开菜单
# ==================================

WEB_DIR="/storage/emulated/0/zcl"
PORT=8081

ok() { echo -e "✅ $1"; }
err() { echo -e "❌ $1"; }

# 服务控制函数
start_services() {
    pkill -f "nginx: master" >/dev/null 2>&1
    pkill -f "php-fpm" >/dev/null 2>&1
    sleep 2
    nginx
    php-fpm --fpm-config $PREFIX/etc/php-fpm.conf -c $PREFIX/etc/php.ini >/dev/null 2>&1 &
    sleep 3
}

stop_services() {
    pkill -f "nginx: master" >/dev/null 2>&1
    pkill -f "php-fpm" >/dev/null 2>&1
    sleep 2
}

show_status() {
    echo -e "\n--- 服务状态 ---"
    pgrep -f "nginx: master" >/dev/null && echo "✅ Nginx 正在运行" || echo "❌ Nginx 未运行"
    pgrep -f "php-fpm" >/dev/null && echo "✅ PHP-FPM 正在运行" || echo "❌ PHP-FPM 未运行"
    echo "📍 访问地址: http://127.0.0.1:$PORT"
}

# 主菜单
while true; do
    echo -e "\n========= tvbox_php 服务控制菜单 ========="
    echo "1) 启动 Nginx + PHP-FPM"
    echo "2) 停止 Nginx + PHP-FPM"
    echo "3) 查看状态"
    echo "4) 打开浏览器"
    echo "5) 重启服务"
    echo "6) 查看日志"
    echo "7) 退出菜单"
    echo "8) 关闭 Termux 后台"
    echo "===================================="
    read -p "请输入选项 [1-8]: " choice

    case "$choice" in
        1)
            start_services
            ok "服务已启动: http://127.0.0.1:$PORT"
            ;;
        2)
            stop_services
            echo "🛑 服务已停止"
            ;;
        3)
            show_status
            ;;
        4)
            termux-open "http://127.0.0.1:$PORT"
            ;;
        5)
            stop_services
            start_services
            ok "服务已重启: http://127.0.0.1:$PORT"
            ;;
        6)
            echo -e "\n--- 最近错误日志 ---"
            tail -10 "$PREFIX/var/log/nginx/error.log" 2>/dev/null || echo "日志文件不存在"
            ;;
        7)
            echo "退出菜单"
            break
            ;;
        8)
            echo "关闭后台进程 & 退出 Termux"
            stop_services
            pkill -f "com.termux" >/dev/null 2>&1
            pkill -f "termux" >/dev/null 2>&1
            exit 0
            ;;
        *)
            echo "无效输入，请输入 1-8"
            ;;
    esac
done
EOF

    chmod +x "$HOME/tvbox_menu.sh"
    ok "独立菜单脚本已创建: $HOME/tvbox_menu.sh"
}

# 主执行流程
echo "🎯 恢复 tvbox_php 完整菜单功能..."

# 设置快捷命令
setup_aliases

# 创建独立菜单脚本
create_menu_script

# 启动菜单
echo -e "\n🎊 菜单功能恢复完成！"
echo "📝 您现在可以："
echo "   - 直接使用快捷命令: tvbox-start, tvbox-stop, tvbox-status"
echo "   - 运行 'tvbox-menu' 打开完整菜单"
echo "   - 运行 'bash tvbox_menu.sh' 打开菜单"

# 显示当前状态
show_status

# 进入菜单
echo -e "\n🚀 进入主菜单..."
menu
