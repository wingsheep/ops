#!/bin/bash
# DNS验证Auth Hook
# 当Certbot需要DNS验证时调用

LOGFILE="/var/log/nginx/dns_auth.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [DNS-AUTH] - $1" | tee -a "$LOGFILE"
}

log "========== DNS验证开始 =========="
log "域名: $CERTBOT_DOMAIN"
log "验证内容: $CERTBOT_VALIDATION"
log "Token: $CERTBOT_TOKEN"

# 显示需要手动添加的DNS记录
cat << EOF

🎯 请手动添加以下DNS TXT记录：

记录类型: TXT
记录名称: _acme-challenge.$CERTBOT_DOMAIN
记录值: $CERTBOT_VALIDATION

步骤:
1. 登录您的DNS管理控制台
2. 添加上述TXT记录
3. 等待DNS记录生效（通常需要1-10分钟）
4. 按任意键继续...

EOF

read -p "DNS记录添加完成后，按Enter继续..."

# 验证DNS记录是否生效
log "验证DNS记录是否生效..."
for i in {1..30}; do
    result=$(dig +short TXT "_acme-challenge.$CERTBOT_DOMAIN" | tr -d '"')
    if [ "$result" = "$CERTBOT_VALIDATION" ]; then
        log "DNS记录验证成功"
        exit 0
    fi
    log "等待DNS记录生效... ($i/30)"
    sleep 10
done

log "错误: DNS记录验证超时"
exit 1 
