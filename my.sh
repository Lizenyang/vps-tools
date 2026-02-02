#!/bin/bash

# =========================================================
# 个人专属运维脚本 - Clean Edition v1.7
# 适配: Debian/Ubuntu/CentOS/Alpine/macOS/Windows
# =========================================================

# --- 颜色定义 (扩充了调色板) ---
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

install_pkg() {
    local pkg_debian=$1
    local pkg_centos=$2
    local pkg_mac=$3
    local pkg_alpine=$4
    
    if [[ "$OS_TYPE" == "debian" ]]; then
        apt update && apt install -y "$pkg_debian"
    elif [[ "$OS_TYPE" == "centos" ]]; then
        yum install -y "$pkg_centos"
    elif [[ "$OS_TYPE" == "macos" ]]; then
        brew install "$pkg_mac"
    elif [[ "$OS_TYPE" == "alpine" ]]; then
        apk add --no-cache "$pkg_alpine"
    fi
}

# --- 功能函数区 ---

run_kejilion_global() {
    curl -sS -O https://raw.githubusercontent.com/kejilion/sh/main/kejilion.sh && chmod +x kejilion.sh && ./kejilion.sh
}
run_kejilion_cn() {
    curl -sS -O https://kejilion.pro/kejilion.sh && chmod +x kejilion.sh && ./kejilion.sh
}

oracle_firewall() {
    if [[ "$OS_TYPE" != "debian" && "$OS_TYPE" != "centos" && "$OS_TYPE" != "alpine" ]]; then echo -e "${RED}仅限 Linux。${PLAIN}"; return; fi
    
    systemctl stop firewalld.service 2>/dev/null
    systemctl disable firewalld.service 2>/dev/null
    rc-service firewalld stop 2>/dev/null
    
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -F
    
    netfilter-persistent save 2>/dev/null || service iptables save 2>/dev/null
    echo -e "${GREEN}✅ 防火墙规则已重置并全放行。${PLAIN}"
}

install_fail2ban() {
    echo -e "${YELLOW}正在配置 Fail2Ban (永久封禁策略)...${PLAIN}"
    # 1. 识别系统并安装
    local LOCAL_OS="unknown"
    if command -v apk >/dev/null; then
        LOCAL_OS="alpine"
        apk update && apk add --no-cache fail2ban && mkdir -p /var/run/fail2ban
    elif command -v apt-get >/dev/null; then
        LOCAL_OS="debian"
        apt-get update && apt-get install -y fail2ban
    elif command -v yum >/dev/null; then
        LOCAL_OS="centos"
        yum install -y epel-release && yum install -y fail2ban
    else
        echo -e "${RED}无法自动安装，请手动安装 Fail2Ban。${PLAIN}"; return
    fi

    # 2. 写入配置
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
    if [ "$LOCAL_OS" == "alpine" ]; then
        echo "logpath = /var/log/messages" >> /etc/fail2ban/jail.local
        echo "backend = auto" >> /etc/fail2ban/jail.local
    fi

    # 3. 启动
    if command -v systemctl >/dev/null; then
        systemctl enable fail2ban && systemctl restart fail2ban
    elif command -v rc-service >/dev/null; then
        rc-update add fail2ban default && rc-service fail2ban restart
    fi
    echo -e "${GREEN}✅ Fail2Ban 部署完成。${PLAIN}"
}

install_traff_x64() {
    if ! command -v docker &> /dev/null; then echo -e "${RED}请先安装 Docker!${PLAIN}"; return; fi
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    docker run --name Dockers -d traffmonetizer/cli_v2 start accept --token FfS7aIWXg3XZuMO+tiau5Y36klu9j4hY3N7AM3X6f6s=
    docker update --restart=always Dockers
    echo -e "${GREEN}✅ Traffmonetizer (AMD64) 已启动。${PLAIN}"
}
install_traff_arm() {
    if ! command -v docker &> /dev/null; then echo -e "${RED}请先安装 Docker!${PLAIN}"; return; fi
    docker pull traffmonetizer/cli_v2:arm64v8
    docker run -i --name cloudsave -d traffmonetizer/cli_v2:arm64v8 start accept --token FfS7aIWXg3XZuMO+tiau5Y36klu9j4hY3N7AM3X6f6s=
    docker update --restart=always cloudsave
    echo -e "${GREEN}✅ Traffmonetizer (ARM64) 已启动。${PLAIN}"
}

install_v2bx_backend() {
    wget -N https://raw.githubusercontent.com/wyx2685/V2bX-script/master/install.sh && bash install.sh
}

kill_tmux() {
    tmux kill-server
    echo -e "${GREEN}✅ 所有 Tmux 会话已清理。${PLAIN}"
}

add_ssh_key() {
    if [[ "$OS_TYPE" == "windows" ]]; then echo -e "${RED}不支持 Windows。${PLAIN}"; return; fi
    local YOUR_PUBLIC_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDF8diyCdxXtq4hnWps7ppjEi0TQcxm/rb+0sjxux2t3gE+299JchpXx+0+1pw5AV/o58ebCNeb6FsjpfLCNIeNxO82kK1/hOgxrlp99hNenCTfZwlAahlB1KnjwdjA11+8temBEioFWN8AO4E6iOjIbbCTteAQhRNXNbpJwWfZHX2O0aNw1Q9JjAfOOT1dKl8C4KKdODhkPGz6M81Xi+oFFh9N0Mq2VqjZ6bQr4DLa8QH2WAEwYYC6GngQthtnTDLPKaqpyF3p5nVSDQ7Z+iKBdftBjNNreq+j0jE2o+iDDUetYWbt8chaZabHtrUODhTmd+vpUhEQWnEPKXKnOvX0hHlFeKgKUlgu7CrDGiqXnJ7oew8zZbLLJfEL1Zac3nFZUObDpzXV0LXemn+OkK1nyJ36UlwZgHfLNrPY6vh3ZEGdD0nhcn2VNELlNp8fv7O10CtiSa4adwNsUMk8lHauR/hiogrRwK7sEn/ze5DAheWO3i+22a+EDPlIKQkEgID7FmKTL7kD0Z5r/Vs2L3lKgJQJ7bCnDoYDcj8mKlzlUezNdoLA/l758keONlzOpwVFfLwQqbI369tb3yRfuwN9vOYfNqSGdv/IRZ/QL614DQ2RZeZKPo2RWDq/KxAautgTQTiodGZZrkxs4Y8W0/l8+/1cFN+BaN/6FB76QNkxBQ== my_vps_key"
    if [ ! -d "/root/.ssh" ]; then mkdir -p /root/.ssh && chmod 700 /root/.ssh; fi
    if command -v chattr &> /dev/null; then chattr -ia /root/.ssh 2>/dev/null; chattr -ia /root/.ssh/authorized_keys 2>/dev/null; fi
    
    if grep -qF "$YOUR_PUBLIC_KEY" /root/.ssh/authorized_keys 2>/dev/null; then
        echo -e "${YELLOW}公钥已存在。${PLAIN}"
    else
        echo "$YOUR_PUBLIC_KEY" >> /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys
        echo -e "${GREEN}✅ 公钥已添加。${PLAIN}"
    fi
    
    # 强化配置
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%F_%T)
    sed -i 's/^PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null || echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config
    sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config 2>/dev/null || echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
    sed -i 's/^ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config 2>/dev/null || echo "ChallengeResponseAuthentication no" >> /etc/ssh/sshd_config
    
    if command -v systemctl >/dev/null 2>&1; then systemctl restart sshd; else service ssh restart 2>/dev/null || rc-service sshd restart; fi
    echo -e "${GREEN}✅ SSH配置已加固 (已禁用密码)。${PLAIN}"
}

install_nezha_stealth() {
    if [[ "$OS_TYPE" == "windows" || "$OS_TYPE" == "macos" ]]; then echo -e "${RED}仅支持 Linux。${PLAIN}"; return; fi
    local NEW_NAME="systemd-private"
    echo -e "${YELLOW}安装探针 + 伪装 (${NEW_NAME})...${PLAIN}"
    curl -L https://raw.githubusercontent.com/nezhahq/scripts/main/agent/install.sh -o agent.sh && chmod +x agent.sh && env NZ_SERVER=152.69.218.38:8008 NZ_TLS=false NZ_CLIENT_SECRET=5PYr2moxoVfay9rlLet3QwbH6PjTknkI ./agent.sh
    if [ $? -ne 0 ]; then echo -e "${RED}安装失败。${PLAIN}"; return; fi
    sleep 5 
    systemctl stop nezha-agent
    if [ -f "/opt/nezha/agent/nezha-agent" ]; then mv "/opt/nezha/agent/nezha-agent" "/opt/nezha/agent/$NEW_NAME"; fi
    sed -i "s|/opt/nezha/agent/nezha-agent|/opt/nezha/agent/$NEW_NAME|g" "/etc/systemd/system/nezha-agent.service"
    systemctl daemon-reload && systemctl start nezha-agent && rm -f agent.sh
    echo -e "${GREEN}✅ 伪装完成！进程名: $NEW_NAME${PLAIN}"
}

clean_traces() {
    history -c
    > ~/.bash_history
    if [ -f ~/.zsh_history ]; then > ~/.zsh_history; fi
    echo -e "${GREEN}✅ 历史痕迹已清理。${PLAIN}"
}

create_shortcut() {
    if [[ "$OS_TYPE" == "windows" ]]; then echo -e "${RED}Windows 不支持。${PLAIN}"; return; fi
    curl -sL "https://raw.githubusercontent.com/Lizenyang/vps-tools/main/my.sh" -o "/usr/bin/y"
    chmod +x "/usr/bin/y"
    echo -e "${GREEN}✅ 快捷键设置成功！输入 'y' 即可使用。${PLAIN}"
}

# --- 新版 UI 界面 ---
show_menu() {
    clear
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${PLAIN}"
    echo -e "${BLUE}▐${PLAIN}  ${PURPLE}个人专属运维工具箱${PLAIN} ${YELLOW}v1.7${PLAIN}                        ${BLUE}▌${PLAIN}"
    echo -e "${BLUE}▐${PLAIN}  系统: ${OS_TYPE} | 架构: ${ARCH}                    ${BLUE}▌${PLAIN}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${PLAIN}"
    echo -e ""
    
    echo -e "${YELLOW}▌ 🚀 脚本集成${PLAIN}"
    echo -e "  ${CYAN}1.${PLAIN} 运行 科技Lion (国外源)"
    echo -e "  ${CYAN}2.${PLAIN} 运行 科技Lion (国内源)"
    echo -e ""

    echo -e "${YELLOW}▌ 🛡️  系统安全${PLAIN}"
    echo -e "  ${CYAN}3.${PLAIN} Oracle 防火墙全放行"
    echo -e "  ${CYAN}4.${PLAIN} 安装 Fail2ban (永久封禁)"
    echo -e "  ${CYAN}5.${PLAIN} 一键添加公钥 (禁用密码)"
    echo -e "  ${CYAN}6.${PLAIN} 清理历史痕迹 (History)"
    echo -e ""

    echo -e "${YELLOW}▌ ⚡ 流量与监控${PLAIN}"
    echo -e "  ${CYAN}7.${PLAIN} 部署 Traffmonetizer (AMD64)"
    echo -e "  ${CYAN}8.${PLAIN} 部署 Traffmonetizer (ARM64)"
    echo -e "  ${CYAN}9.${PLAIN} 哪吒探针 + 进程伪装"
    echo -e ""

    echo -e "${YELLOW}▌ 🔧 面板与维护${PLAIN}"
    echo -e "  ${CYAN}10.${PLAIN} 配置 V2bX 后端"
    echo -e "  ${CYAN}11.${PLAIN} 杀掉所有 Tmux 会话"
    echo -e "  ${CYAN}12.${PLAIN} 设置快捷键 'y'"
    echo -e ""

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${PLAIN}"
    echo -e "  ${RED}0. 退出脚本${PLAIN}"
    echo -e ""
    read -p " 请输入选项 [0-12]: " choice

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
