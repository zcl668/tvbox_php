#!/data/data/com.termux/files/usr/bin/bash
# Termux 一键修复 dpkg/apt 错误脚本
# 使用方法: bash fix_termux.sh

echo -e "\e[33m[1/6] 删除可能存在的锁文件...\e[0m"
rm -f /data/data/com.termux/files/usr/var/lib/dpkg/lock
rm -f /data/data/com.termux/files/usr/var/lib/dpkg/lock-frontend
rm -f /data/data/com.termux/files/usr/var/cache/apt/archives/lock

echo -e "\e[33m[2/6] 修复未完成的包配置...\e[0m"
dpkg --configure -a

echo -e "\e[33m[3/6] 修复损坏或未满足依赖...\e[0m"
apt install -f -y

echo -e "\e[33m[4/6] 清理缓存和不需要的包...\e[0m"
apt clean
apt autoremove -y

echo -e "\e[33m[5/6] 更新源和升级所有包...\e[0m"
apt update && apt upgrade -y

echo -e "\e[33m[6/6] 检查 dpkg 状态...\e[0m"
dpkg --audit

echo -e "\e[32m✅ Termux dpkg/apt 修复完成！\e[0m"
