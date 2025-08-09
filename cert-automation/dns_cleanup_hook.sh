#!/bin/bash
# DNS验证Cleanup Hook
# DNS验证完成后清理临时记录

LOGFILE="/var/log/nginx/dns_cleanup.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [DNS-CLEANUP] - $1" | tee -a "$LOGFILE"
}

log "========== DNS验证清理开始 =========="
log "域名: $CERTBOT_DOMAIN"
log "验证内容: $CERTBOT_VALIDATION"

cat << EOF

🧹 DNS验证完成，可以删除临时DNS记录了：

记录类型: TXT
记录名称: _acme-challenge.$CERTBOT_DOMAIN
记录值: $CERTBOT_VALIDATION

请登录DNS管理控制台删除此临时记录。

EOF

log "DNS验证清理完成" 
