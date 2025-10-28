#!/bin/bash
# Certbot Post Hook - 证书续期后重载nginx（增强调试版）
set -Eeuo pipefail

LOGFILE="/var/log/nginx/certbot_post.log"

# 1) 固定 PATH，避免找不到 nginx/systemctl
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# 2) 固定二进制与配置文件路径（如你的路径不同，请改这里）
NGINX_BIN="${NGINX_BIN:-/usr/sbin/nginx}"
NGINX_CONF="${NGINX_CONF:-/etc/nginx/nginx.conf}"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') [POST] - $1" | tee -a "$LOGFILE"
}

log "========== Certbot Post Hook 开始 =========="
log "PATH=$PATH"
log "whoami=$(id -u -n) uid=$(id -u)"
log "NGINX_BIN=$NGINX_BIN"
log "NGINX_CONF=$NGINX_CONF"

# 3) 显式指定配置文件，并抓取输出与退出码
if out="$("$NGINX_BIN" -t -c "$NGINX_CONF" 2>&1)"; then
  log "nginx配置检查通过：$out"
  if systemctl reload nginx; then
    log "nginx重载成功"
  else
    code=$?
    log "错误: nginx重载失败 (exit=$code)"
    # 打印最近的 systemd 日志有助排查（可选）
    journalctl -u nginx -n 50 --no-pager 2>&1 | tee -a "$LOGFILE" || true
    exit $code
  fi
else
  code=$?
  log "错误: nginx配置检查失败 (exit=$code)"
  log "nginx -t 输出：$out"
  # 尝试再跑一次并把详细输出写日志（可选）
  "$NGINX_BIN" -t -c "$NGINX_CONF" -q 2>>"$LOGFILE" || true
  exit $code
fi

log "========== Certbot Post Hook 结束 =========="
