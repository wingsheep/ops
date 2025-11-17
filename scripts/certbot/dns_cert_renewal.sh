#!/bin/bash
# DNS验证方式获取Let's Encrypt证书
# 适用于域名已经解析到CDN的情况

DOMAIN="file.example.com"
EMAIL="1306750238@qq.com"
LOG_FILE="/var/log/nginx/dns_cert_renewal.log"

# 日志函数
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "========== DNS验证证书获取开始 =========="

# 手动DNS验证
manual_dns_verification() {
    log "使用手动DNS验证模式..."
    
    # 获取证书（手动模式）
    certbot certonly \
        --manual \
        --preferred-challenges=dns \
        --email "$EMAIL" \
        --server https://acme-v02.api.letsencrypt.org/directory \
        --agree-tos \
        --manual-public-ip-logging-ok \
        -d "$DOMAIN" \
        --manual-auth-hook /etc/nginx/cert-automation/dns_auth_hook.sh \
        --manual-cleanup-hook /etc/nginx/cert-automation/dns_cleanup_hook.sh
}

# 主流程
main() {
    # 仅使用「手动DNS验证 + Aliyun CLI Hooks」
    manual_dns_verification
    
    # 检查证书是否获取成功
    if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
        log "证书获取成功"
        
        # 启用HTTPS配置
        if [ ! -f "/etc/nginx/.https_enabled" ]; then
            log "启用HTTPS配置..."
            sed -i '/# HTTPS server for file.example.com/,/# }/s/^    # /    /' /etc/nginx/nginx.conf
            
            if nginx -t && systemctl reload nginx; then
                touch "/etc/nginx/.https_enabled"
                log "HTTPS配置启用成功"
            else
                log "HTTPS配置启用失败"
            fi
        fi
        
        # 上传到七牛云
        source /etc/nginx/cert-automation/qiniu_env.sh
        cd /etc/nginx/cert-automation
        python3 upload_cert_to_qiniu.py
        
    else
        log "证书获取失败"
        exit 1
    fi
}

main "$@" 
