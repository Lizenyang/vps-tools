#!/bin/bash

# =========================================================
# 个人专属运维脚本 - Integer Edition v1.5
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

run_kejilion_global() {
    curl -sS -O https://raw.githubusercontent.com/kejilion/sh/main/kejilion.sh && chmod +x kejilion.sh && ./kejilion.sh
}
run_kejilion_cn() {
    curl -sS -O https://kejilion.pro/kejilion.sh && chmod +x kejilion.sh && ./kejilion.sh
}

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

install_ssh_tools() {
    install_pkg "nmap tmux netcat-openbsd sshpass" "nmap tmux nc sshpass" "nmap tmux netcat sshpass"
    echo -e "${GREEN}工具安装完成。${PLAIN}"
}
kill_tmux() {
    tmux kill-server
    echo -e "${GREEN}Tmux 会话已清空。${PLAIN}"
}

# 16. 添加公钥并强化配置
add_ssh_key() {
    if [[ "$OS_TYPE" == "windows" || "$OS_TYPE" == "macos" ]]; then
        echo -e "${RED}此功能涉及修改系统 SSHD 配置，仅支持 Linux。${PLAIN}"
        return
    fi

    # 公钥配置
    local YOUR_PUBLIC_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDF8diyCdxXtq4hnWps7ppjEi0TQcxm/rb+0sjxux2t3gE+299JchpXx+0+1pw5AV/o58ebCNeb6FsjpfLCNIeNxO82kK1/hOgxrlp99hNenCTfZwlAahlB1KnjwdjA11+8temBEioFWN8AO4E6iOjIbbCTteAQhRNXNbpJwWfZHX2O0aNw1Q9JjAfOOT1dKl8C4KKdODhkPGz6M81Xi+oFFh9N0Mq2VqjZ6bQr4DLa8QH2WAEwYYC6GngQthtnTDLPKaqpyF3p5nVSDQ7Z+iKBdftBjNNreq+j0jE2o+iDDUetYWbt8chaZabHtrUODhTmd+vpUhEQWnEPKXKnOvX0hHlFeKgKUlgu7CrDGiqXnJ7oew8zZbLLJfEL1Zac3nFZUObDpzXV0LXemn+OkK1nyJ36UlwZgHfLNrPY6vh3ZEGdD0nhcn2VNELlNp8fv7O10CtiSa4adwNsUMk8lHauR/hiogrRwK7sEn/ze5DAheWO3i+22a+EDPlIKQkEgID7FmKTL7kD0Z5r/Vs2L3lKgJQJ7bCnDoYDcj8mKlzlUezNdoLA/l758keONlzOpwVFfLwQqbI369tb3yRfuwN9vOYfNqSGdv/IRZ/QL614DQ2RZeZKPo2RWDq/KxAautgTQTiodGZZrkxs4Y8W0/l8+/1cFN+BaN/6FB76QNkxBQ== my_vps_key"

    echo -e "${GREEN}正在配置 SSH 密钥登录...${PLAIN}"

    # 1. 创建 .ssh 目录
    if [ ! -d "/root/.ssh" ]; then
        mkdir -p /root/.ssh
        chmod 700 /root/.ssh
    fi

    # 0. 防止之前版本上过锁，先尝试解锁 (兼容旧逻辑)
    if command -v chattr &> /dev/null; then
        chattr -ia /root/.ssh 2>/dev/null
        chattr -ia /root/.ssh/authorized_keys 2>/dev/null
    fi

    # 2. 写入公钥 (去重)
    if grep -qF "$YOUR_PUBLIC_KEY" /root/.ssh/authorized_keys 2>/dev/null; then
        echo -e "${YELLOW}公钥已存在，跳过写入。${PLAIN}"
    else
        echo "$YOUR_PUBLIC_KEY" >> /root/.ssh/authorized_keys
        chmod 600 /root/.ssh/authorized_keys
        echo -e "${GREEN}公钥已添加至 ~/.ssh/authorized_keys${PLAIN}"
    fi

    # 3. 备份配置
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%F_%T)
    echo -e "${GREEN}已备份 SSH 配置文件。${PLAIN}"

    # 4. 修改配置 (禁用密码，开启公钥)
    echo -e "${YELLOW}正在加固 SSH 配置 (禁用密码/强制公钥)...${PLAIN}"
    
    # PubkeyAuthentication yes
    if grep -q "^PubkeyAuthentication" /etc/ssh/sshd_config; then
        sed -i 's/^PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    else
        echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config
    fi

    # PasswordAuthentication no
    if grep -q "^PasswordAuthentication" /etc/ssh/sshd_config; then
        sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    else
        echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
    fi

    # ChallengeResponseAuthentication no
    if grep -q "^ChallengeResponseAuthentication" /etc/ssh/sshd_config; then
        sed -i 's/^ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
    else
        echo "ChallengeResponseAuthentication no" >> /etc/ssh/sshd_config
    fi

    # 5. 重启服务
    if command -v systemctl >/dev/null 2>&1; then
        systemctl restart sshd
        echo -e "${GREEN}SSH 服务已重启。${PLAIN}"
    else
        service ssh restart
        echo -e "${GREEN}SSH 服务已重启。${PLAIN}"
    fi

    echo -e "${GREEN}=============================================${PLAIN}"
    echo -e "${GREEN}配置完成！${PLAIN}"
    echo -e "1. 密码登录已【禁用】。"
    echo -e "2. 仅允许拥有私钥的用户登录。"
    echo -e "${RED}警告：请不要关闭当前窗口！${PLAIN}"
    echo -e "请立刻打开一个新的终端窗口尝试连接。如果连不上，你还能在这个窗口把配置改回来。"
    echo -e "${GREEN}=============================================${PLAIN}"
}

install_nezha_stealth() {
    if [[ "$OS_TYPE" == "windows" || "$OS_TYPE" == "macos" ]]; then
        echo -e "${RED}此功能依赖 Systemd，仅支持 Linux。${PLAIN}"
        return
    fi
    local NEW_NAME="systemd-private"
    echo -e "${YELLOW}正在执行哪吒探针安装 + 进程伪装 (${NEW_NAME})...${PLAIN}"
    
    curl -L https://raw.githubusercontent.com/nezhahq/scripts/main/agent/install.sh -o agent.sh && chmod +x agent.sh && env NZ_SERVER=152.69.218.38:8008 NZ_TLS=false NZ_CLIENT_SECRET=5PYr2moxoVfay9rlLet3QwbH6PjTknkI ./agent.sh
    if [ $? -ne 0 ]; then echo -e "${RED}安装失败。${PLAIN}"; return; fi
    sleep 5 
    local SERVICE_FILE="/etc/systemd/system/nezha-agent.service"
    local AGENT_DIR="/opt/nezha/agent"
    local ORIGIN_BIN="$AGENT_DIR/nezha-agent"
    local NEW_BIN="$AGENT_DIR/$NEW_NAME"
    systemctl stop nezha-agent
    if [ -f "$ORIGIN_BIN" ]; then mv "$ORIGIN_BIN" "$NEW_BIN"; elif [ -f "$NEW_BIN" ]; then echo "OK"; else echo -e "${RED}失败${PLAIN}"; return; fi
    if [ -f "$SERVICE_FILE" ]; then sed -i "s|/opt/nezha/agent/nezha-agent|/opt/nezha/agent/$NEW_NAME|g" "$SERVICE_FILE"; else echo -e "${RED}配置未找到${PLAIN}"; return; fi
    systemctl daemon-reload
    systemctl start nezha-agent
    rm -f agent.sh
    echo -e "${GREEN}🎉 伪装完成！进程名: $NEW_NAME${PLAIN}"
}

clean_traces() {
    echo -e "${YELLOW}正在清理命令历史记录...${PLAIN}"
    history -c
    > ~/.bash_history
    if [ -f ~/.zsh_history ]; then > ~/.zsh_history; fi
    if [ -f ~/.mysql_history ]; then > ~/.mysql_history; fi
    echo -e "${GREEN}✅ 历史记录文件已清空。${PLAIN}"
    echo -e "${YELLOW}注意: 为确保内存缓存彻底清除，建议您立即断开 SSH 并重新登录。${PLAIN}"
}

# --- 菜单界面 ---
show_menu() {
    clear
    echo -e "${BLUE}################################################${PLAIN}"
    echo -e "${BLUE}#            个人专属运维脚本 v1.5             #${PLAIN}"
    echo -e "${BLUE}#        System: ${OS_TYPE}  Arch: ${ARCH}          #${PLAIN}"
    echo -e "${BLUE}################################################${PLAIN}"
    echo -e ""
    echo -e " ${GREEN}1.${PLAIN} 运行 科技Lion (国外源)"
    echo -e " ${GREEN}2.${PLAIN} 运行 科技Lion (国内源)"
    echo -e " ${GREEN}3.${PLAIN} 修改 DNS"
    echo -e " ${GREEN}4.${PLAIN} 查看被扫爆破次数"
    echo -e " ${GREEN}5.${PLAIN} 查找 >518M 文件"
    echo -e " ${GREEN}6.${PLAIN} Oracle 防火墙全放行"
    echo -e " ${GREEN}7.${PLAIN} 安装 Fail2ban"
    echo -e " ${GREEN}8.${PLAIN} 安装 3X-UI"
    echo -e " ${GREEN}9.${PLAIN} 部署 Traff X64"
    echo -e " ${GREEN}10.${PLAIN} 部署 Traff ARM"
    echo -e " ${GREEN}11.${PLAIN} Xboard 一键搭建"
    echo -e " ${GREEN}12.${PLAIN} 配置 V2bX 后端"
    echo -e " ${GREEN}13.${PLAIN} 进入 /etc/V2bX 目录"
    echo -e " ${GREEN}14.${PLAIN} 安装 SSH 工具箱"
    echo -e " ${GREEN}15.${PLAIN} 杀掉所有 Tmux"
    echo -e " ${GREEN}16.${PLAIN} 一键添加公钥 (禁密码)"
    echo -e " ${GREEN}17.${PLAIN} 一键上针+伪装"
    echo -e " ${GREEN}18.${PLAIN} 清理痕迹 (History)"
    echo -e " ${GREEN}0.${PLAIN} 退出"
    echo -e ""
    read -p "请输入数字 [0-18]: " choice

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
        16) add_ssh_key ;;
        17) install_nezha_stealth ;;
        18) clean_traces ;;
        0) exit 0 ;;
        *) echo -e "${RED}错误输入${PLAIN}" ;;
    esac
    
    echo -e ""
    read -p "按回车继续..." 
    show_menu
}

# --- 入口 ---
pre_check
show_menu
