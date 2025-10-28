#!/bin/bash
# 自动化Let's Encrypt证书续期并上传到七牛云CDN
# 建议添加到crontab中每月执行一次

set -e

DOMAIN="file.qinsuda.xyz"
LOG_FILE="/var/log/nginx/cert_renewal.log"
# 安装后的脚本目录（保持与安装脚本一致）
SCRIPT_DIR="/etc/nginx/cert-automation"

# 日志函数
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# 检查nginx配置
check_nginx_config() {
    log "检查nginx配置..."
    if nginx -t; then
        log "nginx配置检查通过"
        return 0
    else
        log "nginx配置检查失败"
        return 1
    fi
}

# 重载nginx配置
reload_nginx() {
    log "重载nginx配置..."
    if systemctl reload nginx; then
        log "nginx重载成功"
        return 0
    else
        log "nginx重载失败"
        return 1
    fi
}

# 获取Let's Encrypt证书
get_certificate() {
    log "开始获取Let's Encrypt证书..."
    
    # 首次获取证书
    if [ ! -d "/etc/letsencrypt/live/$DOMAIN" ]; then
        log "首次获取证书..."
        certbot certonly --webroot \
            -w /usr/share/nginx/html \
            -d "$DOMAIN" \
            --email 1306750238@qq.com \
            --agree-tos \
            --non-interactive
    else
        log "续期现有证书..."
        certbot renew --quiet
    fi
    
    if [ $? -eq 0 ]; then
        log "证书获取/续期成功"
        return 0
    else
        log "证书获取/续期失败"
        return 1
    fi
}

# 启用HTTPS配置
enable_https() {
    log "启用HTTPS配置..."
    
    # 检查证书文件是否存在
    if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
        # 取消注释HTTPS服务器配置
        sed -i '/# HTTPS server for file.qinsuda.xyz/,/# }/s/^    # /    /' /etc/nginx/nginx.conf
        
        if check_nginx_config; then
            reload_nginx
            log "HTTPS配置启用成功"
            return 0
        else
            log "HTTPS配置启用失败，回滚..."
            # 回滚配置
            sed -i '/# HTTPS server for file.qinsuda.xyz/,/# }/s/^    /    # /' /etc/nginx/nginx.conf
            return 1
        fi
    else
        log "证书文件不存在"
        return 1
    fi
}

# 上传证书到七牛云
upload_to_qiniu() {
    log "开始上传证书到七牛云..."
    
    # 加载七牛云环境变量（若存在）
    if [ -f "$SCRIPT_DIR/qiniu_env.sh" ]; then
        # shellcheck disable=SC1091
        source "$SCRIPT_DIR/qiniu_env.sh"
    fi

    # 检查环境变量
    if [ -z "$QINIU_ACCESS_KEY" ] || [ -z "$QINIU_SECRET_KEY" ]; then
        log "错误：未设置七牛云环境变量 QINIU_ACCESS_KEY 和 QINIU_SECRET_KEY"
        return 1
    fi
    
    # 执行Python脚本
    cd "$SCRIPT_DIR"
    if python3 upload_cert_to_qiniu.py; then
        log "证书上传到七牛云成功"
        return 0
    else
        log "证书上传到七牛云失败"
        return 1
    fi
}

# 主流程
main() {
    log "========== 开始自动化证书续期流程 =========="
    
    # 1. 检查nginx配置
    if ! check_nginx_config; then
        log "流程终止：nginx配置检查失败"
        exit 1
    fi
    
    # 2. 获取/续期证书
    if ! get_certificate; then
        log "流程终止：证书获取失败"
        exit 1
    fi
    
    # 3. 启用HTTPS配置（仅首次需要）
    if [ ! -f "/etc/nginx/.https_enabled" ]; then
        if enable_https; then
            touch "/etc/nginx/.https_enabled"
        else
            log "流程终止：HTTPS配置启用失败"
            exit 1
        fi
    fi
    
    # 4. 上传证书到七牛云
    if ! upload_to_qiniu; then
        log "警告：证书上传到七牛云失败，但本地证书已更新"
        exit 1
    fi
    
    log "========== 自动化证书续期流程完成 =========="
}

# 执行主流程
main "$@" 
