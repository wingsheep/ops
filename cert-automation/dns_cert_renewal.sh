#!/bin/bash
# DNS验证方式获取Let's Encrypt证书
# 适用于域名已经解析到CDN的情况

DOMAIN="file.qinsuda.xyz"
EMAIL=""
LOG_FILE="/var/log/nginx/dns_cert_renewal.log"

# 日志函数
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "========== DNS验证证书获取开始 =========="

# 检查是否安装了DNS插件
check_dns_plugin() {
    # 检查阿里云DNS插件
    if pip3 list | grep -q certbot-dns-aliyun; then
        echo "aliyun"
        return 0
    fi
    
    # 检查腾讯云DNS插件
    if pip3 list | grep -q certbot-dns-tencentcloud; then
        echo "tencentcloud"
        return 0
    fi
    
    # 检查Cloudflare DNS插件
    if pip3 list | grep -q certbot-dns-cloudflare; then
        echo "cloudflare"
        return 0
    fi
    
    return 1
}

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

# 自动DNS验证
auto_dns_verification() {
    local plugin=$1
    log "使用自动DNS验证模式: $plugin"
    
    case $plugin in
        "aliyun")
            certbot certonly \
                --dns-aliyun \
                --dns-aliyun-credentials /etc/nginx/aliyun-credentials.ini \
                --email "$EMAIL" \
                --agree-tos \
                --non-interactive \
                -d "$DOMAIN"
            ;;
        "cloudflare")
            certbot certonly \
                --dns-cloudflare \
                --dns-cloudflare-credentials /etc/nginx/cloudflare-credentials.ini \
                --email "$EMAIL" \
                --agree-tos \
                --non-interactive \
                -d "$DOMAIN"
            ;;
        *)
            log "不支持的DNS插件: $plugin"
            return 1
            ;;
    esac
}

# 主流程
main() {
    # 检查DNS插件
    dns_plugin=$(check_dns_plugin)
    if [ $? -eq 0 ]; then
        log "检测到DNS插件: $dns_plugin"
        auto_dns_verification "$dns_plugin"
    else
        log "未检测到DNS插件，使用手动验证模式"
        manual_dns_verification
    fi
    
    # 检查证书是否获取成功
    if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
        log "证书获取成功"
        
        # 启用HTTPS配置
        if [ ! -f "/etc/nginx/.https_enabled" ]; then
            log "启用HTTPS配置..."
            sed -i '/# HTTPS server for file.qinsuda.xyz/,/# }/s/^    # /    /' /etc/nginx/nginx.conf
            
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
