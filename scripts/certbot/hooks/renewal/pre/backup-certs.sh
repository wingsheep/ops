#!/bin/bash
# Certbot Pre Hook - 证书续期前备份现有证书
# 每次certbot运行前都会执行

LOGFILE="/var/log/nginx/certbot_pre.log"
BACKUP_DIR="/var/backups/letsencrypt"

# 日志函数
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [PRE] - $1" | tee -a "$LOGFILE"
}

log "========== Certbot Pre Hook 开始 =========="

# 创建备份目录
mkdir -p "$BACKUP_DIR"

# 备份现有证书
if [ -d "/etc/letsencrypt/live" ]; then
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_FILE="$BACKUP_DIR/letsencrypt_backup_$TIMESTAMP.tar.gz"
    
    log "开始备份Let's Encrypt证书..."
    if tar -czf "$BACKUP_FILE" -C /etc letsencrypt/live letsencrypt/archive 2>/dev/null; then
        log "证书备份成功: $BACKUP_FILE"
        
        # 保留最新5个备份，删除旧备份
        cd "$BACKUP_DIR"
        ls -t letsencrypt_backup_*.tar.gz | tail -n +6 | xargs rm -f 2>/dev/null
        log "清理旧备份完成"
    else
        log "警告: 证书备份失败"
    fi
else
    log "跳过备份: 未找到现有证书"
fi

log "========== Certbot Pre Hook 结束 ==========" 
