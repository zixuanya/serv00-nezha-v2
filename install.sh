#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'

# 获取当前用户的根目录路径
USER_HOME=$(eval echo ~$USER)
NEZHA_PATH="${USER_HOME}/nezha"
NEZHA_CONFIG_FILE="${NEZHA_PATH}/config.yml"
AGENT_TAR_FILE="${NEZHA_PATH}/nezha-agent-v1.5.2-linux-amd64.tar.gz"  # 更换为实际下载链接的文件名
KEEPALIVE_SCRIPT="$NEZHA_PATH/keepalive.sh"

# 打印欢迎信息
clear
echo -e "${CYAN}============================================="
echo -e "        ${GREEN}Nezha Agent V1 安装器${RESET}"
echo -e "============================================="
echo -e "${BLUE}1.${RESET} ${YELLOW}安装 Nezha Agent V1${RESET}"
echo -e "${BLUE}2.${RESET} ${YELLOW}卸载 Nezha Agent V1${RESET}"
echo -e "${BLUE}3.${RESET} ${YELLOW}更改 Nezha Agent V1 配置${RESET}"
echo -e "${BLUE}0.${RESET} ${RED}退出脚本${RESET}"
echo -e "============================================="
echo -n "请输入选择(1/2/3/0): "

# 用户输入选项
read choice

# 检查 Nezha 路径是否存在，如果不存在则创建
check_and_create_nezha_dir() {
    if [ ! -d "$NEZHA_PATH" ]; then
        echo -e "${YELLOW}未找到 Nezha 目录，正在创建目录: $NEZHA_PATH${RESET}"
        mkdir -p "$NEZHA_PATH"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}目录创建成功: $NEZHA_PATH${RESET}"
        else
            echo -e "${RED}创建目录失败，请检查权限或手动创建目录。${RESET}"
            exit 1
        fi
    fi
}

# 生成 UUID
generate_uuid() {
    echo $(uuidgen)
}

# 安装 Nezha Agent
install_nezha_agent() {
    check_and_create_nezha_dir

    echo -e "${CYAN}正在从 GitHub 下载 Nezha Agent v1.5.2版本...${RESET}"

    # 下载 Nezha Agent v1.5.2 版本（更新为实际的下载链接）
    AGENT_DOWNLOAD_URL="https://github.com/nezhahq/agent/releases/download/v1.5.2/nezha-agent-linux-amd64-v1.5.2.tar.gz"

    echo -e "${GREEN}正在下载 Nezha Agent v1.5.2...${RESET}"
    wget -q --show-progress "$AGENT_DOWNLOAD_URL" -O "$AGENT_TAR_FILE"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}下载失败，请检查网络连接或手动下载。${RESET}"
        exit 1
    fi

    # 解压并安装
    echo -e "${YELLOW}下载完成，正在解压...${RESET}"
    tar -xzf "$AGENT_TAR_FILE" -C "$NEZHA_PATH"

    if [ $? -ne 0 ]; then
        echo -e "${RED}解压失败。${RESET}"
        exit 1
    fi

    # 清理安装包
    rm -f "$AGENT_TAR_FILE"

    # 设置执行权限
    chmod +x "$NEZHA_PATH/nezha-agent-linux-amd64"

    # 生成配置文件
    echo -e "${CYAN}开始配置 Nezha Agent...${RESET}"
    change_nezha_config
}

# 更改 Nezha 配置
change_nezha_config() {
    # 停止当前的 keepalive.sh 脚本
    if [ -f "$KEEPALIVE_SCRIPT" ]; then
        echo -e "${YELLOW}停止 keepalive.sh 保活脚本...${RESET}"
        pkill -f "$KEEPALIVE_SCRIPT"
        echo -e "${GREEN}keepalive.sh 保活脚本已停止。${RESET}"
    fi

    # 停止正在运行的 nezha-agent 进程
    echo -e "${YELLOW}停止 nezha-agent 进程...${RESET}"
    pkill -f "nezha-agent-linux-amd64"
    echo -e "${GREEN}nezha-agent 进程已停止。${RESET}"

    # 删除当前的 config.yml 配置文件
    if [ -f "$NEZHA_CONFIG_FILE" ]; then
        rm -f "$NEZHA_CONFIG_FILE"
        echo -e "${YELLOW}旧的 config.yml 配置文件已删除。${RESET}"
    fi

    # 重新询问用户配置
    echo -e "${CYAN}请输入以下配置信息：${RESET}"

    echo -n "请输入 client_secret: "
    read CLIENT_SECRET

    echo -n "请输入 server 地址: "
    read SERVER

    echo -n "是否启用 TLS (true/false): "
    read TLS

    UUID=$(generate_uuid)

    # 创建新的 config.yml 文件
    cat <<EOL > "$NEZHA_CONFIG_FILE"
client_secret: "$CLIENT_SECRET"
debug: false
disable_auto_update: true
disable_command_execute: false
disable_force_update: true
disable_nat: false
disable_send_query: false
gpu: false
insecure_tls: false
ip_report_period: 1800
report_delay: 3
self_update_period: 0
server: "$SERVER"
skip_connection_count: false
skip_procs_count: false
temperature: false
tls: $TLS
use_gitee_to_upgrade: false
use_ipv6_country_code: false
uuid: "$UUID"
EOL

    echo -e "${GREEN}新的 config.yml 配置文件已生成。${RESET}"

    # 启动 Nezha Agent
    echo -e "${CYAN}启动 Nezha Agent...${RESET}"
    nohup "$NEZHA_PATH/nezha-agent-linux-amd64" -c "$NEZHA_CONFIG_FILE" &

    # 更新保活脚本
    echo -e "${CYAN}更新 keepalive.sh 保活脚本...${RESET}"
    cat <<EOL > "$KEEPALIVE_SCRIPT"
#!/bin/bash
while true
do
    nohup "$NEZHA_PATH/nezha-agent-linux-amd64" -c "$NEZHA_CONFIG_FILE" &
    sleep 60
done
EOL

    chmod +x "$KEEPALIVE_SCRIPT"
    echo -e "${GREEN}keepalive.sh 保活脚本已更新并正在运行。${RESET}"

    echo -e "${GREEN}Nezha Agent 配置已更改并重新启动！${RESET}"
}

# 卸载 Nezha Agent
uninstall_nezha_agent() {
    echo -e "${RED}正在卸载 Nezha Agent V1...${RESET}"

    # 停止 keepalive.sh 保活脚本
    if [ -f "$KEEPALIVE_SCRIPT" ]; then
        echo -e "${YELLOW}停止 keepalive.sh 保活脚本...${RESET}"
        pkill -f "$KEEPALIVE_SCRIPT"
        echo -e "${GREEN}keepalive.sh 保活脚本已停止。${RESET}"
    fi

    # 停止正在运行的 nezha-agent 进程
    echo -e "${YELLOW}停止 nezha-agent 进程...${RESET}"
    pkill -f "nezha-agent-linux-amd64"
    echo -e "${GREEN}nezha-agent 进程已停止。${RESET}"

    # 删除 Nezha 目录及相关文件
    if [ -d "$NEZHA_PATH" ]; then
        rm -rf "$NEZHA_PATH"
        echo -e "${GREEN}Nezha Agent 已卸载成功。${RESET}"
    else
        echo -e "${RED}Nezha Agent 未安装，无法卸载。${RESET}"
    fi
}

# 处理用户选择
case $choice in
    1)
        # 安装 Nezha Agent
        install_nezha_agent
        ;;
    2)
        # 卸载 Nezha Agent
        uninstall_nezha_agent
        ;;
    3)
        # 更改 Nezha 配置
        change_nezha_config
        ;;
    0)
        # 退出脚本
        echo -e "${RED}退出脚本...${RESET}"
        exit 0
        ;;
    *)
        # 输入无效
        echo -e "${RED}无效的选择，请重新运行脚本并选择有效选项.${RESET}"
        exit 1
        ;;
esac
