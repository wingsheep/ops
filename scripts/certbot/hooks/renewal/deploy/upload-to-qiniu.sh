#!/bin/bash
# Certbot Deploy Hook - 证书续期成功后自动上传到七牛云
# 增强版：支持多域名配置，优化通知格式
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

LOGFILE="/var/log/nginx/certbot_deploy.log"
SCRIPT_DIR="/etc/nginx/cert-automation"

# 预加载环境变量（获取 webhook 和域名配置）
if [ -f "$SCRIPT_DIR/qiniu_env.sh" ]; then
    source "$SCRIPT_DIR/qiniu_env.sh"
fi

# 企业微信 Webhook（可从环境变量配置）
WECOM_WEBHOOK="${WECOM_WEBHOOK:-https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=2a592fdb-0de0-408f-86b0-b761c549057b}"

# 需要上传到七牛云的域名列表（可从环境变量配置）
QINIU_DOMAINS="${QINIU_DOMAINS:-file.qinsuda.xyz}"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [DEPLOY] - $1" | tee -a "$LOGFILE"
}

# 企业微信通知函数
send_wecom_notification() {
    local content="$1"
    curl -s -X POST "$WECOM_WEBHOOK" \
        -H 'Content-Type: application/json' \
        -d "{
            \"msgtype\": \"markdown\",
            \"markdown\": {
                \"content\": \"$content\"
            }
        }" || true
}

# 检查域名是否需要上传到七牛云
should_upload_to_qiniu() {
    local domain="$1"
    for qiniu_domain in $QINIU_DOMAINS; do
        if [[ "$domain" == "$qiniu_domain" ]]; then
            return 0
        fi
    done
    return 1
}

log "========== Certbot Deploy Hook 开始 =========="
log "证书域名: $RENEWED_DOMAINS"
log "证书路径: $RENEWED_LINEAGE"

# 如果是 dry-run 模式（测试证书），跳过上传
if [ "${CERTBOT_TEST_CERT:-false}" = "true" ]; then
    log "检测到 Dry-run 模式 (测试证书)，跳过七牛云上传"
    exit 0
fi

# 获取主域名（第一个域名）
PRIMARY_DOMAIN=$(echo "$RENEWED_DOMAINS" | awk '{print $1}')

# 检查是否需要上传到七牛云
upload_triggered=false
for domain in $RENEWED_DOMAINS; do
    if should_upload_to_qiniu "$domain"; then
        log "检测到 $domain 证书续期，开始上传到七牛云..."
        upload_triggered=true
        
        # 加载环境变量
        if [ -f "$SCRIPT_DIR/qiniu_env.sh" ]; then
            source "$SCRIPT_DIR/qiniu_env.sh"
            log "已加载七牛云环境变量"
        else
            log "错误: 未找到七牛云环境变量文件"
            exit 1
        fi
        
        # 检查环境变量
        if [ -z "$QINIU_ACCESS_KEY" ] || [ -z "$QINIU_SECRET_KEY" ]; then
            log "错误: 七牛云环境变量未设置"
            exit 1
        fi
        
        # 启用HTTPS配置（如果还未启用）
        if [ ! -f "/etc/nginx/.https_enabled" ]; then
            log "启用HTTPS配置..."
            sed -i '/# HTTPS server for file.qinsuda.xyz/{n;:a;/# }/!{s/^    # /    /;n;ba}}' /etc/nginx/nginx.conf
            
            if nginx -t && systemctl reload nginx; then
                touch "/etc/nginx/.https_enabled"
                log "HTTPS配置启用成功"
            else
                log "HTTPS配置启用失败，但继续上传证书"
            fi
        fi
        
        # 切换到脚本目录
        cd /etc/nginx/cert-automation
        
        # 执行上传脚本
        if python3 upload_cert_to_qiniu.py; then
            log "证书上传到七牛云成功"
            
            # 获取证书有效期
            cert_path="/etc/letsencrypt/live/$domain/fullchain.pem"
            expire_date=$(openssl x509 -in "$cert_path" -noout -enddate 2>/dev/null | cut -d= -f2)
            expire_formatted=$(date -d "$expire_date" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "$expire_date")
            
            log "证书自动续期并上传完成 - $(date)"
            
            # 清理临时DNS记录提醒（如果使用DNS验证）
            if [ -f "/tmp/dns_validation_used" ]; then
                log "提醒: 如使用手动DNS验证，请记得删除临时DNS TXT记录"
                rm -f "/tmp/dns_validation_used"
            fi
        else
            log "错误: 证书上传到七牛云失败"
            
            # 发送失败通知
            fail_content="## ❌ 七牛云证书上传失败

**域名**: $domain
**时间**: $(date '+%Y-%m-%d %H:%M:%S')
**服务器**: $(hostname)

请检查日志: \`/var/log/nginx/certbot_deploy.log\`"
            
            send_wecom_notification "$fail_content"
            exit 1
        fi
        
        break  # 只上传第一个匹配的域名
    fi
done

if [ "$upload_triggered" = false ]; then
    log "跳过: 当前证书不在七牛云上传列表中"
    log "续期域名: $RENEWED_DOMAINS"
    log "七牛云域名: $QINIU_DOMAINS"
fi

log "========== Certbot Deploy Hook 结束 =========="
