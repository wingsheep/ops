#!/bin/bash
set -euo pipefail

# 固定 PATH，确保能找到 aliyun / jq / dig
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

LOG="/var/log/letsencrypt/dns-auth-aliyun.log"
CACHE_DIR="/var/lib/letsencrypt/aliyun-txt-cache"
PROFILE="certbot"

log(){ echo "$(date '+%F %T') [CLEANUP] $*" | tee -a "$LOG"; }

REQ_DOMAIN="${CERTBOT_DOMAIN}"
REQ_VALUE="${CERTBOT_VALIDATION}"

ID_FILE="${CACHE_DIR}/${REQ_DOMAIN}.${REQ_VALUE}.id"
if [ ! -f "$ID_FILE" ]; then
  log "未找到缓存的 RecordId（可能已手动删除或上一步失败），改为按值查询删除"
  # 备用路径：按 SubDomain 搜索并匹配 Value 删除（更稳，但慢一点）
  # 判 Zone
  find_zone() {
    local d="$1"
    while true; do
      if dig +short SOA "$d" >/dev/null; then
        if [ -n "$(dig +short SOA "$d")" ]; then echo "$d"; return 0; fi
      fi
      d="${d#*.}"
      [ -z "$d" ] && return 1
    done
  }
  ZONE="$(find_zone "$REQ_DOMAIN")" || { log "无法判 Zone"; exit 0; }
  RR="_acme-challenge"
  LEFT="${REQ_DOMAIN%.$ZONE}"
  if [ -n "$LEFT" ] && [ "$LEFT" != "$REQ_DOMAIN" ]; then
    RR="_acme-challenge.${LEFT}"
  fi
  JSON="$(aliyun --profile "$PROFILE" alidns DescribeSubDomainRecords \
    --SubDomain "${RR}.${ZONE}" --Type TXT 2>/dev/null || true)"
  IDS=$(echo "$JSON" | jq -r ".DomainRecords.Record[]? | select(.Type==\"TXT\" and .Value==\"$REQ_VALUE\") | .RecordId")
  if [ -z "$IDS" ]; then
    log "未找到需要清理的TXT，直接结束"
    exit 0
  fi
  while read -r id; do
    [ -z "$id" ] && continue
    log "删除 TXT RecordId=$id"
    aliyun --profile "$PROFILE" alidns DeleteDomainRecord --RecordId "$id" >/dev/null || true
  done <<< "$IDS"
  exit 0
fi

REC_ID="$(cat "$ID_FILE")"
if [ -n "$REC_ID" ]; then
  log "按缓存 RecordId 删除 TXT: $REC_ID"
  aliyun --profile "$PROFILE" alidns DeleteDomainRecord --RecordId "$REC_ID" >/dev/null || true
  rm -f "$ID_FILE"
else
  log "缓存文件为空，跳过"
fi

log "CLEANUP 完成"
