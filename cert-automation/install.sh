#!/bin/bash
# Let's Encrypt证书自动化系统安装脚本

set -e

INSTALL_DIR="/etc/nginx/cert-automation"
LOG_FILE="/var/log/nginx/install.log"

# 日志函数
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# 检查root权限
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "错误: 请使用root权限运行此脚本"
        exit 1
    fi
}

# 安装依赖
install_dependencies() {
    log "安装系统依赖..."
    
    # 检查包管理器
    if command -v yum &> /dev/null; then
        yum install -y python3 python3-pip certbot
    elif command -v apt &> /dev/null; then
        apt update
        apt install -y python3 python3-pip certbot
    else
        log "错误: 不支持的系统，请手动安装 python3, pip3, certbot"
        exit 1
    fi
    
    # 安装Python依赖
    log "安装Python依赖..."
    cd "$INSTALL_DIR"
    pip3 install -r requirements.txt
}

# 设置权限
set_permissions() {
    log "设置文件权限..."
    chmod +x "$INSTALL_DIR"/*.sh
    chmod +x "$INSTALL_DIR"/*.py
    chmod 600 "$INSTALL_DIR"/*.example
}

# 创建目录
create_directories() {
    log "创建必要目录..."
    mkdir -p /var/log/nginx
    mkdir -p /var/backups/letsencrypt
}

# 显示安装后指引
show_guide() {
    cat << EOF

🎉 安装完成！

📁 项目目录: $INSTALL_DIR
📝 主文档: $INSTALL_DIR/README.md

🚀 下一步操作:

1. 配置七牛云环境变量:
   cd $INSTALL_DIR
   cp qiniu_env.example qiniu_env.sh
   vim qiniu_env.sh

2. 根据域名解析情况选择:

   🌐 域名解析到CDN (DNS验证):
   cp aliyun-credentials.ini.example aliyun-credentials.ini
   vim aliyun-credentials.ini
   ./dns_cert_renewal.sh

   🏠 域名解析到服务器 (HTTP验证):
   ./auto_cert_renewal.sh

3. 查看详细文档:
   cat README.md

📞 获取帮助:
   - 查看日志: tail -f /var/log/nginx/install.log
   - 检查配置: nginx -t
   - 测试证书: certbot certificates

EOF
}

# 主安装流程
main() {
    log "========== 开始安装Let's Encrypt证书自动化系统 =========="
    
    check_root
    create_directories
    install_dependencies
    set_permissions
    
    log "安装完成"
    show_guide
}

main "$@" 
