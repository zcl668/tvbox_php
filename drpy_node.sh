#!/bin/bash

# 定义颜色
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
PH='\033[35m'
QS='\033[36m'
NC='\033[0m' # No Color

# 检查当前用户是否为root用户
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}错误：此脚本需要以root用户身份运行。${NC}"
    exit 1
fi

# 删除功能函数
delete_project() {
    echo -e "${RED}======================================================================${NC}"
    echo -e "${RED}                  警告：即将删除 drpy-node 项目${NC}"
    echo -e "${RED}======================================================================${NC}"
    
    # 自动查找项目目录
    local project_dirs=(
        "$(pwd)/drpy-node"
        "/root/drpy-node"
        "/home/*/drpy-node"
        "/opt/drpy-node"
        "/www/wwwroot/drpy-node"
        "/www/wwwroot/anru.8518898.xyz/drpy-node"
        "$(dirname "$(pwd)")/drpy-node"
    )
    
    local found_dirs=()
    for dir in "${project_dirs[@]}"; do
        # 展开通配符
        for expanded_dir in $dir; do
            if [ -d "$expanded_dir" ]; then
                found_dirs+=("$expanded_dir")
            fi
        done
    done
    
    # 额外查找 /www/wwwroot/ 目录下的所有 drpy-node 项目
    if [ -d "/www/wwwroot" ]; then
        echo -e "${YELLOW}正在搜索 /www/wwwroot/ 目录下的 drpy-node 项目...${NC}"
        while IFS= read -r -d '' dir; do
            if [ -d "$dir" ]; then
                found_dirs+=("$dir")
                echo -e "${GREEN}找到项目: $dir${NC}"
            fi
        done < <(find "/www/wwwroot" -maxdepth 2 -type d -name "drpy-node" -print0 2>/dev/null)
    fi
    
    if [ ${#found_dirs[@]} -eq 0 ]; then
        echo -e "${YELLOW}未找到 drpy-node 项目目录。${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}找到以下 drpy-node 项目目录：${NC}"
    for i in "${!found_dirs[@]}"; do
        echo -e "${YELLOW}$((i+1)). ${found_dirs[$i]}${NC}"
    done
    
    if [ ${#found_dirs[@]} -eq 1 ]; then
        local selected_dir="${found_dirs[0]}"
        echo -e "${YELLOW}自动选择目录: $selected_dir${NC}"
    else
        echo -ne "${YELLOW}请选择要删除的目录编号 (1-${#found_dirs[@]}) 默认选择1: ${NC}"
        read -t 10 choice
        choice=${choice:-"1"}
        
        if [[ ! "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#found_dirs[@]} ]; then
            echo -e "${RED}无效选择，使用默认选择1。${NC}"
            choice=1
        fi
        
        local selected_dir="${found_dirs[$((choice-1))]}"
    fi
    
    echo -e "${YELLOW}此操作将删除以下内容：${NC}"
    echo -e "${YELLOW}1. 项目目录: $selected_dir${NC}"
    echo -e "${YELLOW}2. PM2 进程: drpyS${NC}"
    echo -e "${YELLOW}3. 相关备份文件${NC}"
    echo -e "${YELLOW}4. Python 虚拟环境${NC}"
    echo -ne "${RED}是否同时删除 Yarn 和 PM2？(y/n) 默认10秒后不删除(n): ${NC}"
    read -t 10 delete_tools
    delete_tools=${delete_tools:-"n"}
    
    echo -ne "${RED}您确定要删除吗？(y/n) 默认10秒后取消(n): ${NC}"
    read -t 10 delete_confirm
    delete_confirm=${delete_confirm:-"n"}
    
    if [[ "$delete_confirm" != "y" && "$delete_confirm" != "Y" ]]; then
        echo -e "${GREEN}用户取消删除操作。${NC}"
        return 1
    fi
    
    # 最终确认
    echo -ne "${RED}请再次确认删除操作，输入 'DELETE' 继续: ${NC}"
    read final_confirm
    if [[ "$final_confirm" != "DELETE" ]]; then
        echo -e "${GREEN}删除操作已取消。${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}开始删除 drpy-node 项目...${NC}"
    
    # 停止并删除PM2进程
    if command -v pm2 >/dev/null 2>&1; then
        echo -e "${YELLOW}正在停止并删除PM2进程...${NC}"
        pm2 stop drpyS 2>/dev/null
        pm2 delete drpyS 2>/dev/null
        pm2 save 2>/dev/null
        echo -e "${GREEN}PM2进程处理完成。${NC}"
    fi
    
    # 删除项目目录
    if [ -d "$selected_dir" ]; then
        echo -e "${YELLOW}正在删除项目目录: $selected_dir ...${NC}"
        rm -rf "$selected_dir"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}项目目录删除成功。${NC}"
        else
            echo -e "${RED}项目目录删除失败，请手动删除。${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}项目目录不存在，跳过删除。${NC}"
    fi
    
    # 删除备份文件（在更多目录中查找）
    echo -e "${YELLOW}正在清理备份文件...${NC}"
    find "/root" -name "*.backup_*" -type f -delete 2>/dev/null
    find "/home" -name "*.backup_*" -type f -delete 2>/dev/null
    find "/opt" -name "*.backup_*" -type f -delete 2>/dev/null
    find "/www/wwwroot" -name "*.backup_*" -type f -delete 2>/dev/null
    find "$(pwd)" -name "*.backup_*" -type f -delete 2>/dev/null
    echo -e "${GREEN}备份文件清理完成。${NC}"
    
    # 删除Python虚拟环境（增加新目录）
    local venv_dirs=(
        "$selected_dir/.venv"
        "/root/drpy-node/.venv"
        "/home/*/drpy-node/.venv"
        "/opt/drpy-node/.venv"
        "/www/wwwroot/drpy-node/.venv"
        "/www/wwwroot/anru.8518898.xyz/drpy-node/.venv"
    )
    
    for venv_dir in "${venv_dirs[@]}"; do
        for expanded_venv in $venv_dir; do
            if [ -d "$expanded_venv" ]; then
                echo -e "${YELLOW}正在删除Python虚拟环境: $expanded_venv ...${NC}"
                rm -rf "$expanded_venv"
                echo -e "${GREEN}Python虚拟环境删除完成。${NC}"
            fi
        done
    done
    
    # 删除Yarn和PM2（如果用户选择）
    if [[ "$delete_tools" == "y" || "$delete_tools" == "Y" ]]; then
        echo -e "${YELLOW}正在删除 Yarn 和 PM2...${NC}"
        
        # 删除Yarn
        if command -v yarn >/dev/null 2>&1; then
            echo -e "${YELLOW}正在删除 Yarn...${NC}"
            npm uninstall -g yarn
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Yarn 删除成功。${NC}"
            else
                echo -e "${RED}Yarn 删除失败。${NC}"
            fi
        else
            echo -e "${YELLOW}Yarn 未安装，跳过删除。${NC}"
        fi
        
        # 删除PM2
        if command -v pm2 >/dev/null 2>&1; then
            echo -e "${YELLOW}正在删除 PM2...${NC}"
            
            # 停止所有PM2进程
            pm2 kill 2>/dev/null
            
            # 删除PM2
            npm uninstall -g pm2
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}PM2 删除成功。${NC}"
            else
                echo -e "${RED}PM2 删除失败。${NC}"
            fi
            
            # 删除PM2相关目录和配置（增加新目录）
            local pm2_dirs=(
                "$HOME/.pm2"
                "/root/.pm2"
                "/home/*/.pm2"
                "/www/wwwroot/.pm2"
            )
            
            for pm2_dir in "${pm2_dirs[@]}"; do
                for expanded_pm2 in $pm2_dir; do
                    if [ -d "$expanded_pm2" ]; then
                        echo -e "${YELLOW}正在删除PM2配置目录: $expanded_pm2 ...${NC}"
                        rm -rf "$expanded_pm2"
                        echo -e "${GREEN}PM2配置目录删除完成。${NC}"
                    fi
                done
            done
        else
            echo -e "${YELLOW}PM2 未安装，跳过删除。${NC}"
        fi
        
        # 删除NVM（可选）
        echo -ne "${YELLOW}是否同时删除 NVM 和 Node.js？(y/n) 默认10秒后不删除(n): ${NC}"
        read -t 10 delete_nvm
        delete_nvm=${delete_nvm:-"n"}
        
        if [[ "$delete_nvm" == "y" || "$delete_nvm" == "Y" ]]; then
            echo -e "${YELLOW}正在删除 NVM 和 Node.js...${NC}"
            
            # 删除NVM目录（增加新目录）
            local nvm_dirs=(
                "$HOME/.nvm"
                "/root/.nvm"
                "/home/*/.nvm"
                "/www/wwwroot/.nvm"
                "$NVM_DIR"
            )
            
            for nvm_dir in "${nvm_dirs[@]}"; do
                for expanded_nvm in $nvm_dir; do
                    if [ -d "$expanded_nvm" ]; then
                        echo -e "${YELLOW}正在删除NVM目录: $expanded_nvm ...${NC}"
                        rm -rf "$expanded_nvm"
                        echo -e "${GREEN}NVM目录删除完成。${NC}"
                    fi
                done
            done
            
            # 从shell配置文件中移除NVM相关行（增加新目录）
            local shell_files=(
                "$HOME/.bashrc"
                "$HOME/.bash_profile"
                "$HOME/.zshrc"
                "$HOME/.profile"
                "/root/.bashrc"
                "/root/.bash_profile"
                "/root/.zshrc"
                "/root/.profile"
                "/www/wwwroot/.bashrc"
                "/www/wwwroot/.bash_profile"
            )
            
            for shell_file in "${shell_files[@]}"; do
                if [ -f "$shell_file" ]; then
                    echo -e "${YELLOW}正在清理 $shell_file 中的NVM配置...${NC}"
                    sed -i '/NVM_DIR/d' "$shell_file" 2>/dev/null
                    sed -i '/nvm.sh/d' "$shell_file" 2>/dev/null
                    sed -i '/nvm bash_completion/d' "$shell_file" 2>/dev/null
                    echo -e "${GREEN}$shell_file 清理完成。${NC}"
                fi
            done
            
            # 删除全局安装的Node.js模块
            if command -v node >/dev/null 2>&1; then
                echo -e "${YELLOW}正在清理全局Node.js模块...${NC}"
                npm list -g --depth=0 2>/dev/null
                npm root -g 2>/dev/null
                echo -e "${GREEN}Node.js 环境清理提示完成。${NC}"
            fi
        else
            echo -e "${YELLOW}保留 NVM 和 Node.js。${NC}"
        fi
    else
        echo -e "${YELLOW}保留 Yarn 和 PM2。${NC}"
    fi
    
    echo -e "${GREEN}drpy-node 项目删除完成！${NC}"
    return 0
}

# 显示菜单函数
show_menu() {
    while true; do
        echo -e "${PH}======================================================================${NC}"
        echo -e "${PH}                    drpy-node 项目管理脚本${NC}"
        echo -e "${PH}======================================================================${NC}"
        echo -e "${GREEN}  1. 安装/更新 drpy-node 项目${NC}"
        echo -e "${RED}  2. 删除 drpy-node 项目${NC}"
        echo -e "${BLUE}  3. 退出脚本${NC}"
        echo -e "${PH}======================================================================${NC}"
        echo -ne "${PH}请选择操作 (1-3) 默认10秒后选择安装/更新(1): ${NC}"
        read -t 10 choice
        choice=${choice:-"1"}
        
        case $choice in
            1)
                echo -e "${GREEN}选择安装/更新操作...${NC}"
                break
                ;;
            2)
                if delete_project; then
                    echo -e "${YELLOW}删除完成，返回主菜单...${NC}"
                    echo -ne "${YELLOW}是否要立即安装新项目？(y/n) 默认10秒后返回主菜单(n): ${NC}"
                    read -t 10 reinstall
                    reinstall=${reinstall:-"n"}
                    if [[ "$reinstall" == "y" || "$reinstall" == "Y" ]]; then
                        echo -e "${GREEN}开始安装新项目...${NC}"
                        break
                    else
                        continue
                    fi
                else
                    echo -e "${YELLOW}删除失败或取消，返回主菜单...${NC}"
                    continue
                fi
                ;;
            3)
                echo -e "${GREEN}退出脚本。${NC}"
                exit 0
                ;;
            *)
                echo -e "${YELLOW}无效选择，使用默认安装/更新操作。${NC}"
                break
                ;;
        esac
    done
}

# 在脚本开始处调用菜单函数
show_menu

# 确认提示（仅在选择安装/更新时显示）
echo -e "${PH}======================================================================${NC}"
echo -e "${PH}  警告：此脚本只适用于群晖、Debian系列系统（包含Ubuntu、Fnos）。${NC}"
echo -e "${YELLOW}  警告：群晖NAS自行安装node套件后使用！！！${NC}"
echo -e "${GREEN}  警告：脚本自动更新需要自行添加任务计划设定运行时间！！！${NC}"
echo -e "${PH}======================================================================${NC}"
echo -ne "${PH}您是否理解并同意继续？(y/n) 默认10秒后确认(y): ${NC}"
read -t 10 confirm
confirm=${confirm:-"y"}
if [[ "$confirm" != "y" ]]; then
    echo -e "${RED}用户取消操作。${NC}"
    exit 1
fi
echo

# 检查是否为群晖系统
is_syno_system() {
    # 群晖系统通常会有 /etc.defaults/VERSION 文件
    if [ -f /etc.defaults/VERSION ]; then
        return 0
    else
        return 1
    fi
}

# 检查是否为群晖系统
if is_syno_system; then
    echo -e "${QS}检测到群晖系统，跳过apt检查。${NC}"
else
    # 检查系统是否支持apt
    if ! command -v apt >/dev/null 2>&1; then
        echo -e "${GREEN}错误：不支持的系统。${NC}"
        exit 1
    fi
fi

# 检查Node.js版本
check_node_version() {
    if command -v node >/dev/null 2>&1; then
        local node_version=$(node -v 2>/dev/null)
        if [[ "$node_version" < "v20.0.0" ]]; then
            echo -e "${YELLOW}Node.js版本低于20.0.0，正在安装Node.js v20以上版本...${NC}"
            install_node_v20
            npm config set registry https://registry.npmmirror.com
        else
            echo -e "${GREEN}Node.js版本符合要求（v20以上），跳过安装。${NC}"
        fi
    else
        echo -e "${YELLOW}Node.js未安装，正在安装Node.js v20...${NC}"
        install_node_v20
        npm config set registry https://registry.npmmirror.com
    fi
}

# 安装Node.js v20以上版本
install_node_v20() {
    echo -e "${YELLOW}正在安装NVM...${NC}"
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash

    # 启用NVM
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

    # 安装Node.js 20
    echo -e "${YELLOW}正在安装Node.js 20...${NC}"
    nvm install 20
    nvm use 20
    nvm alias default 20

    echo -e "${GREEN}Node.js 20安装完成。${NC}"
}

# 检查NVM是否存在，如果不存在则安装
if [ -s "$HOME/.nvm/nvm.sh" ]; then
    echo -e "${GREEN}NVM已安装，跳过NVM安装。${NC}"
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
else
    echo -e "${YELLOW}NVM未安装，正在安装NVM...${NC}"
    curl -o- https://gitee.com/RubyMetric/nvm-cn/raw/main/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    echo -e "${GREEN}NVM安装完成。${NC}"
fi

# 安装Yarn和PM2
install_yarn_and_pm2() {
    if command -v yarn >/dev/null 2>&1; then
        echo -e "${GREEN}Yarn已安装，跳过Yarn安装。${NC}"
        yarn config set registry https://registry.yarnpkg.com
    else
        echo -e "${YELLOW}Yarn未安装，正在安装Yarn...${NC}"
        npm install -g yarn
        yarn config set registry https://registry.yarnpkg.com
        if [ $? -ne 0 ]; then
            echo -e "${RED}Yarn安装失败，请手动安装Yarn后重试。${NC}"
            exit 1
        fi
        echo -e "${GREEN}Yarn安装成功。${NC}"
    fi

    if command -v pm2 >/dev/null 2>&1; then
        echo -e "${GREEN}PM2已安装，跳过PM2安装。${NC}"
    else
        echo -e "${YELLOW}PM2未安装，正在安装PM2...${NC}"
        npm install -g pm2
        if [ $? -ne 0 ]; then
            echo -e "${RED}PM2安装失败，请手动安装PM2后重试。${NC}"
            exit 1
        fi
        echo -e "${GREEN}PM2安装成功。${NC}"
    fi
}

# 执行Node.js版本检查
check_node_version

# 安装Yarn和PM2
install_yarn_and_pm2

# 提示用户输入需要创建的目录，30秒后自动使用当前目录
echo -ne "${PH}请输入需要创建的目录路径（30秒内无输入则使用当前目录）:${NC}"
read -t 30 dir_path
echo
# 根据用户输入设置目录
if [[ -n "$dir_path" ]]; then
    mkdir -p "$dir_path" && cd "$dir_path"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}目录 '$dir_path' 创建并进入成功。${NC}"
        REPO_DIR="$dir_path"
    else
        echo -e "${RED}目录 '$dir_path' 创建失败，使用当前目录。${NC}"
        REPO_DIR=$(pwd)
    fi
else
    echo -e "${YELLOW}已超时，使用当前目录：$(pwd)${NC}"
    REPO_DIR=$(pwd)
fi

# 远程仓库地址
REMOTE_REPO="https://git-proxy.playdreamer.cn/hjdhnx/drpy-node.git"

# 代理远程仓库地址
echo -e "${YELLOW}如果拉取不顺利，请在脚本中找到\$REMOTE_REPO自行注释修改为kk代理地址${NC}"
#REMOTE_REPO="https://kkgithub.com/hjdhnx/drpy-node.git"

# 项目名称
PROJECT_NAME="drpy-node"

# 获取设备IP地址
get_device_ip() {
    # 使用curl获取公网IP地址
    IP=$(curl -s https://ipinfo.io/ip 2>/dev/null || curl -s https://api.ipify.org 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$IP" ]; then
        echo -e "${QS}=        设备IP地址：$IP${NC}"
        echo -e "${QS}=           公网IP自行打码${NC}"
        return 0
    else
        echo -e "${RED}无法获取设备IP地址。${NC}"
        return 1
    fi
}

# 获取设备局域网IP地址
get_local_ip() {
    # 使用ip命令获取局域网IP地址
    local ip=$(ip addr show scope global 2>/dev/null | grep inet | grep -v inet6 | grep -v '127.0.0.1' | awk '{print $2}' | cut -d/ -f1 | head -n1)
    if [ -n "$ip" ]; then
        echo "$ip"
    else
        echo "127.0.0.1"
    fi
}

# 获取局域网IP地址
LOCAL_IP=$(get_local_ip)

# 定义创建env.json文件的函数
create_env_json() {
    local env_json_path="$1/config/env.json"
    
    # 检查env.json文件是否存在
    if [ ! -f "$env_json_path" ]; then
        echo -e "${YELLOW}env.json文件不存在，正在创建...${NC}"
        mkdir -p "$(dirname "$env_json_path")"
        # 创建env.json文件并填充默认内容
        cat > "$env_json_path" <<EOF
{
  "ali_token": "",
  "ali_refresh_token": "",
  "quark_cookie": "",
  "uc_cookie": "",
  "bili_cookie": "",
  "thread": "10",
  "enable_dr2": "1",
  "enable_py": "2"
}
EOF
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}env.json文件创建成功。${NC}"
        else
            echo -e "${RED}env.json文件创建失败。${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}env.json文件已存在，无需创建。${NC}"
    fi
}

# 定义创建.env文件的函数
create_default_env() {
    local env_path="$1/.env"
    local env_development_path="$1/.env.development"
    
    # 检查.env文件是否存在
    if [ ! -f "$env_path" ] && [ -f "$env_development_path" ]; then
        echo -e "${YELLOW}.env文件不存在，正在使用.env.development作为模板创建...${NC}"
        # 使用.env.development作为模板创建.env文件
        cp "$env_development_path" "$env_path"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}.env文件创建成功。${NC}"
        else
            echo -e "${RED}.env文件创建失败。${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}.env文件已存在，无需创建。${NC}"
    fi
}

# 定义初始化.env文件的函数
initialize_default_env() {
    local env_path="$1/.env"
    local env_development_path="$1/.env.development"
    
    # 检查.env文件是否存在
    if [ ! -f "$env_path" ] && [ -f "$env_development_path" ]; then
        echo -e "${YELLOW}.env文件不存在，正在使用.env.development作为模板创建...${NC}"
        # 提示用户输入自定义值，并设置30秒超时
        echo -ne "${YELLOW}请输入网盘入库密码（30秒内无输入则使用默认值'drpys'直接回车可跳过）：${NC}"
        read -t 30 cookie_auth_code
        echo
        if [ -z "$cookie_auth_code" ]; then
            cookie_auth_code="drpys"
        fi

        echo -ne "${YELLOW}请输入登录用户名（30秒内无输入则使用默认值'admin'直接回车可跳过）：${NC}"
        read -t 30 api_auth_name
        echo
        if [ -z "$api_auth_name" ]; then
            api_auth_name="admin"
        fi

        echo -ne "${YELLOW}请输入登录密码（30秒内无输入则使用默认值'drpys'直接回车可跳过）：${NC}"
        read -t 30 api_auth_code
        echo
        if [ -z "$api_auth_code" ]; then
            api_auth_code="drpys"
        fi

        echo -ne "${YELLOW}请输入订阅PWD值（30秒内无输入则使用默认值'dzyyds'直接回车可跳过）：${NC}"
        read -t 30 api_pwd
        echo
        if [ -z "$api_pwd" ]; then
            api_pwd="dzyyds"
        fi

        # 使用.env.development作为模板创建.env文件，并替换自定义值
        cp "$env_development_path" "$env_path"
        if [ $? -eq 0 ]; then
            sed -i "s|COOKIE_AUTH_CODE = .*|COOKIE_AUTH_CODE = $cookie_auth_code|g" "$env_path"
            sed -i "s|API_AUTH_NAME = .*|API_AUTH_NAME = $api_auth_name|g" "$env_path"
            sed -i "s|API_AUTH_CODE = .*|API_AUTH_CODE = $api_auth_code|g" "$env_path"
            sed -i "s|API_PWD = .*|API_PWD = $api_pwd|g" "$env_path"
            echo -e "${GREEN}.env文件创建成功。${NC}"
        else
            echo -e "${RED}.env文件创建失败。${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}.env文件已存在，无需创建。${NC}"
    fi
}

# 定义读取.env文件参数的函数
read_env_params() {
    if [ -f ".env" ]; then
        # 读取.env文件中的参数值，考虑等号前后的空格
        COOKIE_AUTH_CODE=$(grep '^COOKIE_AUTH_CODE' .env 2>/dev/null | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | cut -d'=' -f2 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        API_AUTH_NAME=$(grep '^API_AUTH_NAME' .env 2>/dev/null | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | cut -d'=' -f2 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        API_AUTH_CODE=$(grep '^API_AUTH_CODE' .env 2>/dev/null | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | cut -d'=' -f2 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        API_PWD=$(grep '^API_PWD' .env 2>/dev/null | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | cut -d'=' -f2 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

        # 输出参数值
        echo -e "${QS}=         当前登录账户: ${API_AUTH_NAME:-未设置}${NC}"
        echo -e "${QS}=         当前登录密码: ${API_AUTH_CODE:-未设置}${NC}"
        echo -e "${QS}=         当前入库密码: ${COOKIE_AUTH_CODE:-未设置}${NC}"
        echo -e "${QS}=         当前订阅pwd值: ${API_PWD:-未设置}${NC}"
    else
        echo -e "${YELLOW}.env文件不存在，使用默认值。${NC}"
    fi
}

# IP显示标识
has_displayed_ip=""
# 显示内网和公网访问地址
display_ip_addresses() {
    echo -e "${QS}==================================================${NC}"
    echo -e "${QS}=         项目主页及相关默认值提示${NC}            "
    echo -e "${QS}= 内网访问地址：http://$LOCAL_IP:5757${NC}     "
    # 调用read_env_params函数来显示.env中的值
    read_env_params
    echo -e "${QS}= ${YELLOW}如需修改以上密码值则自行修改源码根目录.env文件${NC}                 "
    get_device_ip
    if [ $? -eq 0 ]; then
        echo -e "${QS}= 公网主页地址：http://$IP:5757${NC}"
        echo -e "${QS}==================================================${NC}"
    else
        echo -e "${RED}无法获取公网IP地址。${NC}"
    fi
}

# 检查项目drpy-node是否存在
if [ -d "$REPO_DIR/$PROJECT_NAME" ]; then
    echo -e "${YELLOW}项目drpy-node存在，跳过克隆步骤，直接执行更新脚本。${NC}"
    cd "$REPO_DIR/$PROJECT_NAME"
else
    echo -e "${YELLOW}项目drpy-node不存在，正在从GitHub克隆项目...${NC}"
    git clone $REMOTE_REPO "$REPO_DIR/$PROJECT_NAME"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}项目drpy-node克隆成功。${NC}"
        cd "$REPO_DIR/$PROJECT_NAME"
        # 克隆后创建env.json和.env文件
        create_env_json "$REPO_DIR/$PROJECT_NAME"
        initialize_default_env "$REPO_DIR/$PROJECT_NAME" # 调用初始化.env文件的函数
        echo -e "${YELLOW}正在执行yarn...${NC}"
        yarn config set registry https://registry.npmmirror.com/
        yarn
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}yarn执行成功，开始安装python环境...${NC}"
            python3 -m venv "$REPO_DIR/$PROJECT_NAME/.venv"
            source "$REPO_DIR/$PROJECT_NAME/.venv/bin/activate"
            pip install -r spider/py/base/requirements.txt -i https://mirrors.cloud.tencent.com/pypi/simple
            echo -e "${GREEN}python执行成功，开始启动项目...${NC}"
            pm2 start index.js --name drpyS
            pm2 save
            pm2 startup
            echo -e "${PH}尝试设置开机自动启动pm2项目，不一定成功，如果以下提示有命令请自行手动输入以确保正常开机启动${NC}"
            if [ -z "$has_displayed_ip" ]; then # 检查是否已经显示过IP地址
                display_ip_addresses
                has_displayed_ip=1 # 设置一个标志，表示已经显示过IP地址
            fi
            exit 0
        else
            echo -e "${RED}yarn执行失败。${NC}"
            exit 1
        fi
    else
        echo -e "${RED}项目drpy-node克隆失败，请检查网络连接或仓库地址是否正确。${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}脚本执行完成！${NC}"
