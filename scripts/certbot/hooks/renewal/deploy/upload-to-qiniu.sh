#!/bin/bash
# Certbot Deploy Hook - 证书续期成功后自动上传到七牛云
# 仅在证书实际续期时执行
# 支持HTTP和DNS验证方式
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
LOGFILE="/var/log/nginx/certbot_deploy.log"
SCRIPT_DIR="/etc/nginx/cert-automation"

# 日志函数
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [DEPLOY] - $1" | tee -a "$LOGFILE"
}

log "========== Certbot Deploy Hook 开始 =========="
log "证书域名: $RENEWED_DOMAINS"
log "证书路径: $RENEWED_LINEAGE"

# 如果是 dry-run 模式（测试证书），跳过上传
if [ "${CERTBOT_TEST_CERT:-false}" = "true" ]; then
    log "检测到 Dry-run 模式 (测试证书)，跳过七牛云上传"
    exit 0
fi

# 检查是否是file.qinsuda.xyz域名
if [[ "$RENEWED_DOMAINS" == *"file.qinsuda.xyz"* ]]; then
    log "检测到file.qinsuda.xyz证书续期，开始上传到七牛云..."
    
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
        
        # 发送成功通知
        log "证书自动续期并上传完成 - $(date)"
        
        # 可以在这里添加其他通知方式，如邮件、钉钉等
        # curl -X POST "your_notification_webhook" -d "file.qinsuda.xyz证书已自动续期并上传到七牛云"
        curl 'https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=2a592fdb-0de0-408f-86b0-b761c549057b' \
        -H 'Content-Type: application/json' \
        -d '
        {
                "msgtype": "text",
                "text": {
                    "content": "file.qinsuda.xyz证书已自动续期并上传到七牛云"
                }
        }'
        # 清理临时DNS记录提醒（如果使用DNS验证）
        if [ -f "/tmp/dns_validation_used" ]; then
            log "提醒: 如使用手动DNS验证，请记得删除临时DNS TXT记录"
            rm -f "/tmp/dns_validation_used"
        fi
        
    else
        log "错误: 证书上传到七牛云失败"
        exit 1
    fi
else
    log "跳过: 不是file.qinsuda.xyz域名的证书续期"
fi

log "========== Certbot Deploy Hook 结束 ==========" 
