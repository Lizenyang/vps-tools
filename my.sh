#!/bin/bash

# =========================================================
# 个人专属运维脚本 - Docker Edition v2.2
# 适配: Debian / Ubuntu / CentOS / Alpine / macOS
# 特性: 新增 Docker 环境自动检测与修复，防止安装失败
# =========================================================

# --- 颜色定义 ---
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
PURPLE='\033[35m'
CYAN='\033[36m'
PLAIN='\033[0m'

# --- 系统与架构检测 ---
ARCH=$(uname -m)
OS_TYPE=""
PACKAGE_MANAGER=""

check_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "linux-musl"* ]]; then
        if [ -f /etc/redhat-release ]; then
            OS_TYPE="centos"
            PACKAGE_MANAGER="yum"
        elif [ -f /etc/debian_version ]; then
            OS_TYPE="debian"
            PACKAGE_MANAGER="apt"
        elif [ -f /etc/alpine-release ]; then
            OS_TYPE="alpine"
            PACKAGE_MANAGER="apk"
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
    if [[ "$OS_TYPE" == "debian" || "$OS_TYPE" == "centos" || "$OS_TYPE" == "alpine" ]]; then
        if [[ $EUID -ne 0 ]]; then
            echo -e "${RED}错误: 请使用 sudo 或 root 权限运行此脚本！${PLAIN}"
            exit 1
        fi
    fi
}

# 通用安装函数
install_pkg() {
    local pkg_debian=$1
    local pkg_centos=$2
    local pkg_mac=$3
    local pkg_alpine=$4
    
    if [[ "$OS_TYPE" == "debian" && -n "$pkg_debian" ]]; then
        apt update -y >/dev/null 2>&1
        apt install -y $pkg_debian
    elif [[ "$OS_TYPE" == "centos" && -n "$pkg_centos" ]]; then
        if command -v dnf &> /dev/null; then dnf install -y $pkg_centos; else yum install -y $pkg_centos; fi
    elif [[ "$OS_TYPE" == "macos" && -n "$pkg_mac" ]]; then
        brew install $pkg_mac
    elif [[ "$OS_TYPE" == "alpine" && -n "$pkg_alpine" ]]; then
        apk update >/dev/null 2>&1
        apk add --no-cache $pkg_alpine
    fi
}

# --- 核心功能模块 ---

# 1-2. 脚本集成
run_kejilion_global() {
    if ! command -v curl &> /dev/null; then install_pkg curl curl curl curl; fi
    curl -sS -O https://raw.githubusercontent.com/kejilion/sh/main/kejilion.sh && chmod +x kejilion.sh && ./kejilion.sh
}
run_kejilion_cn() {
    if ! command -v curl &> /dev/null; then install_pkg curl curl curl curl; fi
    curl -sS -O https://kejilion.pro/kejilion.sh && chmod +x kejilion.sh && ./kejilion.sh
}

# 3. 防火墙
oracle_firewall() {
    if [[ "$OS_TYPE" == "windows" || "$OS_TYPE" == "macos" ]]; then echo -e "${RED}非 Linux 系统跳过。${PLAIN}"; return; fi
    echo -e "${YELLOW}正在清理防火墙规则...${PLAIN}"
    systemctl stop firewalld 2>/dev/null
    systemctl disable firewalld 2>/dev/null
    rc-service firewalld stop 2>/dev/null
    rc-update del firewalld 2>/dev/null
    
    if ! command -v iptables &> /dev/null; then install_pkg iptables iptables "" iptables; fi
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -F
    if command -v netfilter-persistent &> /dev/null; then netfilter-persistent save; elif command -v service &> /dev/null; then service iptables save 2>/dev/null; fi
    echo -e "${GREEN}✅ 防火墙规则已重置并全放行。${PLAIN}"
}

# 4. Fail2Ban
install_fail2ban() {
    echo -e "${YELLOW}正在配置 Fail2Ban (永久封禁策略)...${PLAIN}"
    if command -v apk >/dev/null; then
        apk update && apk add --no-cache fail2ban && mkdir -p /var/run/fail2ban
    elif command -v apt-get >/dev/null; then
        apt-get update && apt-get install -y fail2ban
    elif command -v yum >/dev/null; then
        yum install -y epel-release && yum install -y fail2ban
    else
        echo -e "${RED}无法自动安装，请手动安装 Fail2Ban。${PLAIN}"; return
    fi
    cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1
[sshd]
enabled = true
port    = ssh
filter  = sshd
bantime  = -1
findtime = 60
maxretry = 3
EOF
    if [[ "$OS_TYPE" == "alpine" ]]; then echo -e "logpath = /var/log/messages\nbackend = auto" >> /etc/fail2ban/jail.local; fi
    if command -v systemctl >/dev/null; then systemctl enable fail2ban && systemctl restart fail2ban; elif command -v rc-service >/dev/null; then rc-update add fail2ban default && rc-service fail2ban restart; fi
    echo -e "${GREEN}✅ Fail2Ban 部署完成。${PLAIN}"
}

# 5. SSH 公钥
add_ssh_key() {
    if [[ "$OS_TYPE" == "windows" ]]; then echo -e "${RED}不支持 Windows。${PLAIN}"; return; fi
    if [[ "$OS_TYPE" == "alpine" && ! -f "/usr/bin/chattr" ]]; then apk add --no-cache e2fsprogs-extra; fi

    local YOUR_PUBLIC_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDF8diyCdxXtq4hnWps7ppjEi0TQcxm/rb+0sjxux2t3gE+299JchpXx+0+1pw5AV/o58ebCNeb6FsjpfLCNIeNxO82kK1/hOgxrlp99hNenCTfZwlAahlB1KnjwdjA11+8temBEioFWN8AO4E6iOjIbbCTteAQhRNXNbpJwWfZHX2O0aNw1Q9JjAfOOT1dKl8C4KKdODhkPGz6M81Xi+oFFh9N0Mq2VqjZ6bQr4DLa8QH2WAEwYYC6GngQthtnTDLPKaqpyF3p5nVSDQ7Z+iKBdftBjNNreq+j0jE2o+iDDUetYWbt8chaZabHtrUODhTmd+vpUhEQWnEPKXKnOvX0hHlFeKgKUlgu7CrDGiqXnJ7oew8zZbLLJfEL1Zac3nFZUObDpzXV0LXemn+OkK1nyJ36UlwZgHfLNrPY6vh3ZEGdD0nhcn2VNELlNp8fv7O10CtiSa4adwNsUMk8lHauR/hiogrRwK7sEn/ze5DAheWO3i+22a+EDPlIKQkEgID7FmKTL7kD0Z5r/Vs2L3lKgJQJ7bCnDoYDcj8mKlzlUezNdoLA/l758keONlzOpwVFfLwQqbI369tb3yRfuwN9vOYfNqSGdv/IRZ/QL614DQ2RZeZKPo2RWDq/KxAautgTQTiodGZZrkxs4Y8W0/l8+/1cFN+BaN/6FB76QNkxBQ== my_vps_key"
    if [ ! -d "/root/.ssh" ]; then mkdir -p /root/.ssh && chmod 700 /root/.ssh; fi
    if command -v chattr &> /dev/null; then chattr -ia /root/.ssh 2>/dev/null; chattr -ia /root/.ssh/authorized_keys 2>/dev/null; fi
    
    if grep -qF "$YOUR_PUBLIC_KEY" /root/.ssh/authorized_keys 2>/dev/null; then echo -e "${YELLOW}公钥已存在。${PLAIN}"; else echo "$YOUR_PUBLIC_KEY" >> /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys; echo -e "${GREEN}✅ 公钥已添加。${PLAIN}"; fi
    
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%F_%T)
    sed -i 's/^PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null || echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config
    sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config 2>/dev/null || echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
    
    if command -v systemctl >/dev/null 2>&1; then systemctl restart sshd; else service ssh restart 2>/dev/null || rc-service sshd restart; fi
    echo -e "${GREEN}✅ SSH配置已加固 (已禁用密码)。${PLAIN}"
}

# 6. 清理痕迹
clean_traces() {
    echo -e "${YELLOW}正在深度清理痕迹...${PLAIN}"
    > ~/.bash_history && > ~/.zsh_history && > ~/.mysql_history && history -c
    echo -e "${GREEN}✅ 硬盘记录已清空。${PLAIN}"
    read -p "❓ 是否强制注销? (y/n): " logout_now
    if [[ "$logout_now" == "y" ]]; then kill -9 $PPID; fi
}

# --- Docker 核心模块 (新增) ---
install_docker() {
    if command -v docker &> /dev/null; then
        echo -e "${GREEN}✅ Docker 已安装: $(docker -v)${PLAIN}"
        return 0
    fi

    echo -e "${YELLOW}⚡ 未检测到 Docker，开始环境检测与自动修复...${PLAIN}"

    # 1. 环境依赖检测与安装
    if [[ "$OS_TYPE" == "alpine" ]]; then
        install_pkg "curl ca-certificates" "curl ca-certificates" "" "curl ca-certificates"
    else
        # Debian/CentOS 需要 curl, wget, gnupg, lsb-release 等
        install_pkg "curl wget gnupg lsb-release ca-certificates" "curl wget yum-utils" "" ""
    fi

    # 2. 开始安装
    echo -e "${YELLOW}⚡ 依赖就绪，开始安装 Docker 引擎...${PLAIN}"
    
    if [[ "$OS_TYPE" == "alpine" ]]; then
        apk add --no-cache docker openrc
        rc-update add docker boot
        service docker start
    elif [[ "$OS_TYPE" == "debian" || "$OS_TYPE" == "centos" ]]; then
        # 使用官方脚本，更稳
        curl -fsSL https://get.docker.com | bash
        if command -v systemctl >/dev/null; then systemctl enable --now docker; elif command -v service >/dev/null; then service docker start; fi
    else
        echo -e "${RED}❌ 无法自动安装 (不支持的系统)。${PLAIN}"
        return 1
    fi

    # 3. 验证
    if command -v docker &> /dev/null; then
        echo -e "${GREEN}✅ Docker 安装成功!${PLAIN}"
    else
        echo -e "${RED}❌ Docker 安装失败，请检查网络或系统源。${PLAIN}"
        return 1
    fi
}

# 7-8. Traffmonetizer (调用新的 Docker 安装函数)
install_traff_x64() {
    # 先确保 Docker 存在
    install_docker || return
    
    # 补充 docker-compose
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${YELLOW}安装 docker-compose...${PLAIN}"
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    fi
    docker run --name Dockers -d traffmonetizer/cli_v2 start accept --token FfS7aIWXg3XZuMO+tiau5Y36klu9j4hY3N7AM3X6f6s=
    docker update --restart=always Dockers
    echo -e "${GREEN}✅ Traffmonetizer (AMD64) 已启动。${PLAIN}"
}
install_traff_arm() {
    install_docker || return
    docker pull traffmonetizer/cli_v2:arm64v8
    docker run -i --name cloudsave -d traffmonetizer/cli_v2:arm64v8 start accept --token FfS7aIWXg3XZuMO+tiau5Y36klu9j4hY3N7AM3X6f6s=
    docker update --restart=always cloudsave
    echo -e "${GREEN}✅ Traffmonetizer (ARM64) 已启动。${PLAIN}"
}

# 9. 哪吒探针
install_nezha_stealth() {
    if [[ "$OS_TYPE" == "windows" || "$OS_TYPE" == "macos" ]]; then echo -e "${RED}仅支持 Linux。${PLAIN}"; return; fi
    if ! command -v curl &> /dev/null; then install_pkg curl curl curl curl; fi

    local NEW_NAME="systemd-private"
    echo -e "${YELLOW}安装探针 + 伪装 (${NEW_NAME})...${PLAIN}"
    curl -L https://raw.githubusercontent.com/nezhahq/scripts/main/agent/install.sh -o agent.sh && chmod +x agent.sh && env NZ_SERVER=152.69.218.38:8008 NZ_TLS=false NZ_CLIENT_SECRET=5PYr2moxoVfay9rlLet3QwbH6PjTknkI ./agent.sh
    if [ $? -ne 0 ]; then echo -e "${RED}安装失败。${PLAIN}"; return; fi
    sleep 5 
    
    if command -v systemctl >/dev/null; then systemctl stop nezha-agent; else rc-service nezha-agent stop 2>/dev/null; fi
    if [ -f "/opt/nezha/agent/nezha-agent" ]; then mv "/opt/nezha/agent/nezha-agent" "/opt/nezha/agent/$NEW_NAME"; fi
    
    # 适配服务文件修改
    if [ -f "/etc/systemd/system/nezha-agent.service" ]; then
        sed -i "s|/opt/nezha/agent/nezha-agent|/opt/nezha/agent/$NEW_NAME|g" "/etc/systemd/system/nezha-agent.service"
        systemctl daemon-reload && systemctl start nezha-agent
    elif [ -f "/etc/init.d/nezha-agent" ]; then
        sed -i "s|/opt/nezha/agent/nezha-agent|/opt/nezha/agent/$NEW_NAME|g" "/etc/init.d/nezha-agent"
        rc-service nezha-agent restart
    fi
    rm -f agent.sh
    echo -e "${GREEN}✅ 伪装完成！进程名: $NEW_NAME${PLAIN}"
}

# 10-12. 维护
install_v2bx_backend() {
    if ! command -v wget &> /dev/null; then install_pkg wget wget wget wget; fi
    wget -N https://raw.githubusercontent.com/wyx2685/V2bX-script/master/install.sh && bash install.sh
}
kill_tmux() {
    if command -v tmux &> /dev/null; then tmux kill-server; echo -e "${GREEN}✅ Tmux 会话已清理。${PLAIN}"; else echo -e "${YELLOW}未安装 Tmux。${PLAIN}"; fi
}
create_shortcut() {
    if [[ "$OS_TYPE" == "windows" ]]; then echo -e "${RED}Windows 不支持。${PLAIN}"; return; fi
    curl -sL "https://raw.githubusercontent.com/Lizenyang/vps-tools/main/my.sh" -o "/usr/bin/y" && chmod +x "/usr/bin/y"
    echo -e "${GREEN}✅ 快捷键设置成功！输入 'y' 即可使用。${PLAIN}"
}

# 13. Kimi 启动
run_kimi_boot() {
    if [[ "$OS_TYPE" == "windows" ]]; then echo -e "${RED}不支持 Windows。${PLAIN}"; return; fi
    echo -e "${YELLOW}🚀 部署 Kimi 环境 (${OS_TYPE})...${PLAIN}"
    case "${OS_TYPE}" in
        debian) install_pkg "python3 python3-pip python3-venv build-essential libssl-dev libffi-dev python3-dev" ;;
        centos) install_pkg "python3 python3-pip python3-devel gcc openssl-devel libffi-devel make" ;;
        alpine) install_pkg "python3 py3-pip python3-dev build-base libffi-dev openssl-dev" ;;
        *) install_pkg "python3 python3-pip python3-venv build-essential" ;;
    esac
    if [ ! -d "venv" ]; then python3 -m venv venv; fi
    ./venv/bin/pip install -i https://pypi.tuna.tsinghua.edu.cn/simple --upgrade pip
    ./venv/bin/pip install -i https://pypi.tuna.tsinghua.edu.cn/simple aiohttp aiosqlite colorama asyncssh paramiko requests
    if [ -f "requirements.txt" ]; then ./venv/bin/pip install -i https://pypi.tuna.tsinghua.edu.cn/simple -r requirements.txt; fi
    if [ -f "main.py" ]; then
        echo -e "${GREEN}✅ 启动 main.py ...${PLAIN}"
        chmod +x main.py
        ./venv/bin/python main.py --attack
    else
        echo -e "${RED}❌ 未找到 main.py！${PLAIN}"
    fi
}

# --- UI 界面 ---
show_menu() {
    clear
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${PLAIN}"
    echo -e "${BLUE}▐${PLAIN}  ${PURPLE}个人专属运维工具箱${PLAIN} ${YELLOW}v2.2${PLAIN}                        ${BLUE}▌${PLAIN}"
    echo -e "${BLUE}▐${PLAIN}  系统: ${OS_TYPE} | 架构: ${ARCH}                    ${BLUE}▌${PLAIN}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${PLAIN}"
    echo -e ""
    
    echo -e "${YELLOW}▌ [ 脚本集成 ]${PLAIN}"
    echo -e "  ${CYAN}1.${PLAIN} 运行 科技Lion (国外源)"
    echo -e "  ${CYAN}2.${PLAIN} 运行 科技Lion (国内源)"
    echo -e ""

    echo -e "${YELLOW}▌ [ 系统安全 ]${PLAIN}"
    echo -e "  ${CYAN}3.${PLAIN} Oracle 防火墙全放行"
    echo -e "  ${CYAN}4.${PLAIN} 安装 Fail2ban (永久封禁)"
    echo -e "  ${CYAN}5.${PLAIN} 一键添加公钥 (禁用密码)"
    echo -e "  ${CYAN}6.${PLAIN} 清理历史痕迹 (History)"
    echo -e ""

    echo -e "${YELLOW}▌ [ 流量与监控 ]${PLAIN}"
    echo -e "  ${CYAN}7.${PLAIN} 部署 Traffmonetizer (AMD64)"
    echo -e "  ${CYAN}8.${PLAIN} 部署 Traffmonetizer (ARM64)"
    echo -e "  ${CYAN}9.${PLAIN} 哪吒探针 + 进程伪装"
    echo -e ""

    echo -e "${YELLOW}▌ [ 维护与项目 ]${PLAIN}"
    echo -e "  ${CYAN}10.${PLAIN} 配置 V2bX 后端"
    echo -e "  ${CYAN}11.${PLAIN} 杀掉所有 Tmux 会话"
    echo -e "  ${CYAN}12.${PLAIN} 设置快捷键 'y'"
    echo -e "  ${CYAN}13.${PLAIN} Kimi 一键启动 (部署+运行)"
    echo -e "  ${CYAN}14.${PLAIN} 安装/修复 Docker 环境"
    echo -e ""

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${PLAIN}"
    echo -e "  ${RED}0. 退出脚本${PLAIN}"
    echo -e ""
    read -p " 请输入选项 [0-14]: " choice

    case $choice in
        1) run_kejilion_global ;;
        2) run_kejilion_cn ;;
        3) oracle_firewall ;;
        4) install_fail2ban ;;
        5) add_ssh_key ;;
        6) clean_traces ;;
        7) install_traff_x64 ;;
        8) install_traff_arm ;;
        9) install_nezha_stealth ;;
        10) install_v2bx_backend ;;
        11) kill_tmux ;;
        12) create_shortcut ;;
        13) run_kimi_boot ;;
        14) install_docker ;;
        0) exit 0 ;;
        *) echo -e "${RED}无效选项，请重试。${PLAIN}" ;;
    esac
    
    echo -e ""
    read -p "按回车继续..." 
    show_menu
}

# --- 入口 ---
pre_check
show_menu
