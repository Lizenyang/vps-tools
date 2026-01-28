#!/bin/bash

# =========================================================
# 个人专属运维脚本 - Integer Edition
# 适配: Debian/Ubuntu/CentOS/Armbian/macOS/Windows(GitBash)
# =========================================================

# --- 颜色定义 ---
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
PLAIN='\033[0m'

# --- 系统与架构检测 ---
ARCH=$(uname -m)
OS_TYPE=""
PACKAGE_MANAGER=""

check_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/redhat-release ]; then
            OS_TYPE="centos"
            PACKAGE_MANAGER="yum"
        elif [ -f /etc/debian_version ]; then
            OS_TYPE="debian"
            PACKAGE_MANAGER="apt"
        else
            OS_TYPE="linux_generic"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS_TYPE="macos"
        PACKAGE_MANAGER="brew"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        OS_TYPE="windows"
        PACKAGE_MANAGER="unknown"
    else
        OS_TYPE="unknown"
    fi
}

# --- 权限与依赖安装 ---
pre_check() {
    check_os
    if [[ "$OS_TYPE" == "debian" || "$OS_TYPE" == "centos" ]]; then
        if [[ $EUID -ne 0 ]]; then
            echo -e "${RED}错误: 请使用 sudo 或 root 权限运行此脚本！${PLAIN}"
            exit 1
        fi
    fi
    echo -e "${BLUE}当前系统: ${OS_TYPE} | 架构: ${ARCH}${PLAIN}"
}

install_pkg() {
    local pkg_debian=$1
    local pkg_centos=$2
    local pkg_mac=$3
    if [[ "$OS_TYPE" == "debian" ]]; then
        apt update && apt install -y "$pkg_debian"
    elif [[ "$OS_TYPE" == "centos" ]]; then
        yum install -y "$pkg_centos"
    elif [[ "$OS_TYPE" == "macos" ]]; then
        brew install "$pkg_mac"
    fi
}

# --- 功能函数区 ---

# 1-2. 科技Lion
run_kejilion_global() {
    curl -sS -O https://raw.githubusercontent.com/kejilion/sh/main/kejilion.sh && chmod +x kejilion.sh && ./kejilion.sh
}
run_kejilion_cn() {
    curl -sS -O https://kejilion.pro/kejilion.sh && chmod +x kejilion.sh && ./kejilion.sh
}

# 3-8. 常用功能
mod_dns() {
    if [[ "$OS_TYPE" == "windows" ]]; then echo -e "${RED}Windows 请手动修改。${PLAIN}"; return; fi
    if ! command -v nano &> /dev/null; then install_pkg nano nano nano; fi
    nano /etc/resolv.conf
}
check_lastb() {
    if [[ "$OS_TYPE" == "windows" ]]; then echo -e "${RED}不支持 Windows。${PLAIN}"; else lastb | wc -l; fi
}
find_big_files() {
    echo -e "${YELLOW}正在查找大于 518M 的文件...${PLAIN}"
    sudo find / -type f -size +518M
}
oracle_firewall() {
    if [[ "$OS_TYPE" != "debian" && "$OS_TYPE" != "centos" ]]; then echo -e "${RED}仅限 Linux。${PLAIN}"; return; fi
    systemctl stop firewalld.service 2>/dev/null
    systemctl disable firewalld.service 2>/dev/null
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -F
    netfilter-persistent save 2>/dev/null || service iptables save 2>/dev/null
    echo -e "${GREEN}防火墙已清理。${PLAIN}"
}
install_fail2ban() {
    if [[ "$OS_TYPE" != "debian" && "$OS_TYPE" != "centos" ]]; then echo -e "${RED}仅限 Linux VPS。${PLAIN}"; return; fi
    install_pkg fail2ban fail2ban fail2ban
    cat > /etc/fail2ban/jail.local <<EOF
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
findtime = 60
bantime = -1
EOF
    if [[ "$OS_TYPE" == "centos" ]]; then sed -i 's|/var/log/auth.log|/var/log/secure|g' /etc/fail2ban/jail.local; fi
    systemctl restart fail2ban
    systemctl enable fail2ban
    echo -e "${GREEN}Fail2ban 配置完成。${PLAIN}"
}
install_3xui() {
    bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
}

# 9-10. Traffmonetizer
install_traff_x64() {
    if ! command -v docker &> /dev/null; then echo -e "${RED}请先安装 Docker!${PLAIN}"; return; fi
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    docker run --name Dockers -d traffmonetizer/cli_v2 start accept --token FfS7aIWXg3XZuMO+tiau5Y36klu9j4hY3N7AM3X6f6s=
    docker update --restart=always Dockers
    echo -e "${GREEN}Traffmonetizer (AMD64) 启动。${PLAIN}"
}
install_traff_arm() {
    if ! command -v docker &> /dev/null; then echo -e "${RED}请先安装 Docker!${PLAIN}"; return; fi
    docker pull traffmonetizer/cli_v2:arm64v8
    docker run -i --name cloudsave -d traffmonetizer/cli_v2:arm64v8 start accept --token FfS7aIWXg3XZuMO+tiau5Y36klu9j4hY3N7AM3X6f6s=
    docker update --restart=always cloudsave
    echo -e "${GREEN}Traffmonetizer (ARM64) 启动。${PLAIN}"
}

# 11-13. V2bX
install_xboard() {
    if ! command -v docker &> /dev/null; then echo -e "${RED}请先安装 Docker!${PLAIN}"; return; fi
    git clone -b compose --depth 1 https://github.com/cedar2025/Xboard
    cd Xboard || return
    docker compose run -it --rm -e ENABLE_SQLITE=true -e ENABLE_REDIS=true -e ADMIN_ACCOUNT=admin@demo.com web php artisan xboard:install
    docker compose up -d
    echo -e "${GREEN}Xboard 部署完成。${PLAIN}"
}
install_v2bx_backend() {
    wget -N https://raw.githubusercontent.com/wyx2685/V2bX-script/master/install.sh && bash install.sh
}
goto_v2bx_dir() {
    if [ -d "/etc/V2bX" ]; then cd /etc/V2bX && $SHELL; else echo -e "${RED}目录不存在。${PLAIN}"; fi
}

# 14-15. SSH Tools
install_ssh_tools() {
    install_pkg "nmap tmux netcat-openbsd sshpass" "nmap tmux nc sshpass" "nmap tmux netcat sshpass"
    echo -e "${GREEN}工具安装完成。${PLAIN}"
}
kill_tmux() {
    tmux kill-server
    echo -e "${GREEN}Tmux 会话已清空。${PLAIN}"
}

# --- 菜单界面 ---
show_menu() {
    clear
    echo -e "${BLUE}################################################${PLAIN}"
    echo -e "${BLUE}#            个人专属运维脚本 v1.1             #${PLAIN}"
    echo -e "${BLUE}#        System: ${OS_TYPE}  Arch: ${ARCH}          #${PLAIN}"
    echo -e "${BLUE}################################################${PLAIN}"
    echo -e ""
    echo -e "${YELLOW}--- 科技Lion 脚本 ---${PLAIN}"
    echo -e " ${GREEN}1.${PLAIN} 运行 科技Lion (国外源)"
    echo -e " ${GREEN}2.${PLAIN} 运行 科技Lion (国内源)"
    echo -e ""
    echo -e "${YELLOW}--- 常用维护 ---${PLAIN}"
    echo -e " ${GREEN}3.${PLAIN} 修改 DNS (/etc/resolv.conf)"
    echo -e " ${GREEN}4.${PLAIN} 查看被扫爆破次数"
    echo -e " ${GREEN}5.${PLAIN} 查找 >518M 文件"
    echo -e " ${GREEN}6.${PLAIN} Oracle 防火墙全放行"
    echo -e " ${GREEN}7.${PLAIN} 安装 Fail2ban (防SSH爆破)"
    echo -e " ${GREEN}8.${PLAIN} 安装 3X-UI 面板"
    echo -e ""
    echo -e "${YELLOW}--- 流量挂机 (Traff) ---${PLAIN}"
    echo -e " ${GREEN}9.${PLAIN} 部署 X64 节点 (Docker)"
    echo -e " ${GREEN}10.${PLAIN} 部署 ARM 节点 (Docker)"
    echo -e ""
    echo -e "${YELLOW}--- 面板搭建 (V2bX) ---${PLAIN}"
    echo -e " ${GREEN}11.${PLAIN} Xboard 一键搭建"
    echo -e " ${GREEN}12.${PLAIN} 配置 V2bX 后端"
    echo -e " ${GREEN}13.${PLAIN} 进入 /etc/V2bX 目录"
    echo -e ""
    echo -e "${YELLOW}--- 工具箱 ---${PLAIN}"
    echo -e " ${GREEN}14.${PLAIN} 安装基础工具 (nmap/tmux/nc...)"
    echo -e " ${GREEN}15.${PLAIN} 杀掉所有 Tmux 会话"
    echo -e ""
    echo -e " ${GREEN}0.${PLAIN} 退出"
    echo -e ""
    read -p "请输入数字 [0-15]: " choice

    case $choice in
        1) run_kejilion_global ;;
        2) run_kejilion_cn ;;
        3) mod_dns ;;
        4) check_lastb ;;
        5) find_big_files ;;
        6) oracle_firewall ;;
        7) install_fail2ban ;;
        8) install_3xui ;;
        9) install_traff_x64 ;;
        10) install_traff_arm ;;
        11) install_xboard ;;
        12) install_v2bx_backend ;;
        13) goto_v2bx_dir ;;
        14) install_ssh_tools ;;
        15) kill_tmux ;;
        0) exit 0 ;;
        *) echo -e "${RED}输入错误，请输入 0-15 之间的数字${PLAIN}" ;;
    esac
    
    echo -e ""
    read -p "按回车继续..." 
    show_menu
}

# --- 入口 ---
pre_check
show_menu
