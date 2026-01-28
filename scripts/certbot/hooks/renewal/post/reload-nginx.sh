#!/bin/bash
# Certbot Post Hook - 证书续期后重载nginx并验证证书状态
# 增强版：添加证书验证和统一消息通知
set -Eeuo pipefail

LOGFILE="/var/log/nginx/certbot_post.log"
SCRIPT_DIR="/etc/nginx/cert-automation"

# 加载环境变量（获取 webhook 配置）
if [ -f "$SCRIPT_DIR/qiniu_env.sh" ]; then
    source "$SCRIPT_DIR/qiniu_env.sh"
fi

# 企业微信 Webhook（可从环境变量配置）
WECOM_WEBHOOK="${WECOM_WEBHOOK:-https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=2a592fdb-0de0-408f-86b0-b761c549057b}"

# 固定 PATH
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# nginx 配置
NGINX_BIN="${NGINX_BIN:-/usr/sbin/nginx}"
NGINX_CONF="${NGINX_CONF:-/etc/nginx/nginx.conf}"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [POST] - $1" | tee -a "$LOGFILE"
}

# 企业微信通知函数 - Markdown 格式
send_wecom_notification() {
    local title="$1"
    local content="$2"
    local color="${3:-info}"  # info=蓝色, warning=橙色, comment=灰色
    
    # 构建 Markdown 消息
    curl -s -X POST "$WECOM_WEBHOOK" \
        -H 'Content-Type: application/json' \
        -d "{
            \"msgtype\": \"markdown\",
            \"markdown\": {
                \"content\": \"$content\"
            }
        }" > /dev/null 2>&1 || true
}

# 获取证书有效期信息
get_cert_info() {
    local domain="$1"
    local cert_path="/etc/letsencrypt/live/$domain/fullchain.pem"
    
    if [ -f "$cert_path" ]; then
        local not_after=$(openssl x509 -in "$cert_path" -noout -enddate 2>/dev/null | cut -d= -f2)
        local not_after_ts=$(date -d "$not_after" +%s 2>/dev/null || echo "0")
        local now_ts=$(date +%s)
        local days_left=$(( (not_after_ts - now_ts) / 86400 ))
        
        # 格式化日期为更友好的格式
        local expire_date=$(date -d "$not_after" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "$not_after")
        echo "$expire_date|$days_left"
    else
        echo "未找到|0"
    fi
}

# 构建证书状态报告
build_cert_report() {
    local report=""
    local all_valid=true
    
    # 等待 certbot 索引刷新
    sleep 2
    certbot update_symlinks 2>/dev/null || true
    
    # 遍历所有证书
    for cert_dir in /etc/letsencrypt/live/*/; do
        [ -d "$cert_dir" ] || continue
        local domain=$(basename "$cert_dir")
        [ "$domain" = "README" ] && continue
        
        local cert_info=$(get_cert_info "$domain")
        local expire_date=$(echo "$cert_info" | cut -d'|' -f1)
        local days_left=$(echo "$cert_info" | cut -d'|' -f2)
        
        if [ "$days_left" -gt 30 ]; then
            report="$report\n> 🟢 **$domain**\n> 到期: $expire_date (${days_left}天)"
        elif [ "$days_left" -gt 7 ]; then
            report="$report\n> 🟡 **$domain**\n> 到期: $expire_date (${days_left}天)"
        else
            report="$report\n> 🔴 **$domain**\n> 到期: $expire_date (${days_left}天)"
            all_valid=false
        fi
    done
    
    echo -e "$report"
}

log "========== Certbot Post Hook 开始 =========="
log "PATH=$PATH"
log "whoami=$(id -u -n) uid=$(id -u)"
log "NGINX_BIN=$NGINX_BIN"
log "NGINX_CONF=$NGINX_CONF"

# nginx 配置检查和重载
nginx_status="成功"
if out="$("$NGINX_BIN" -t -c "$NGINX_CONF" 2>&1)"; then
    log "nginx配置检查通过：$out"
    if systemctl reload nginx; then
        log "nginx重载成功"
    else
        code=$?
        log "错误: nginx重载失败 (exit=$code)"
        nginx_status="失败"
        journalctl -u nginx -n 50 --no-pager 2>&1 | tee -a "$LOGFILE" || true
    fi
else
    code=$?
    log "错误: nginx配置检查失败 (exit=$code)"
    log "nginx -t 输出：$out"
    nginx_status="配置错误"
fi

# 构建证书状态报告
log "正在验证所有证书状态..."
cert_report=$(build_cert_report)
log "证书状态报告生成完成"

# 检查七牛云上传状态（从 deploy hook 日志读取）
qiniu_status="未触发"
if grep -q "证书上传到七牛云成功" /var/log/nginx/certbot_deploy.log 2>/dev/null; then
    last_upload=$(grep "证书上传到七牛云成功" /var/log/nginx/certbot_deploy.log | tail -1)
    if echo "$last_upload" | grep -q "$(date '+%Y-%m-%d')"; then
        qiniu_status="✅ 已上传"
    fi
fi

# 发送统一通知
current_time=$(date '+%Y-%m-%d %H:%M:%S')
notification_content="## 🔐 SSL证书续期完成

**服务器**: $(hostname)
**时间**: $current_time

### 📋 证书状态
$cert_report

### ⚙️ 服务状态
> nginx 重载: **$nginx_status**
> 七牛云 CDN: **$qiniu_status**

---
*由 Certbot 自动续期系统发送*"

log "发送企业微信通知..."
send_wecom_notification "SSL证书续期完成" "$notification_content"
log "通知发送完成"

log "========== Certbot Post Hook 结束 =========="
