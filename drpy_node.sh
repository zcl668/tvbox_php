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
    
    # 删除备份文件（在当前目录和项目目录中）
    echo -e "${YELLOW}正在清理备份文件...${NC}"
    find "/root" -name "*.backup_*" -type f -delete 2>/dev/null
    find "/home" -name "*.backup_*" -type f -delete 2>/dev/null
    find "/opt" -name "*.backup_*" -type f -delete 2>/dev/null
    find "$(pwd)" -name "*.backup_*" -type f -delete 2>/dev/null
    echo -e "${GREEN}备份文件清理完成。${NC}"
    
    # 删除Python虚拟环境
    local venv_dirs=(
        "$selected_dir/.venv"
        "/root/drpy-node/.venv"
        "/home/*/drpy-node/.venv"
        "/opt/drpy-node/.venv"
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
            
            # 删除PM2相关目录和配置
            local pm2_dirs=(
                "$HOME/.pm2"
                "/root/.pm2"
                "/home/*/.pm2"
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
            
            # 删除NVM目录
            local nvm_dirs=(
                "$HOME/.nvm"
                "/root/.nvm"
                "/home/*/.nvm"
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
            
            # 从shell配置文件中移除NVM相关行
            local shell_files=(
                "$HOME/.bashrc"
                "$HOME/.bash_profile"
                "$HOME/.zshrc"
                "$HOME/.profile"
                "/root/.bashrc"
                "/root/.bash_profile"
                "/root/.zshrc"
                "/root/.profile"
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

# ... 其余脚本内容保持不变 ...
