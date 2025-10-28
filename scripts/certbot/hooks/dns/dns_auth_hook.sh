#!/bin/bash
# dns_auth_hook.sh - Certbot manual-auth-hook for Aliyun AliDNS (auto zone detect)
# 说明：
# 1) 使用 Aliyun CLI 自动创建 _acme-challenge TXT 记录并等待生效
# 2) 从当前 AK 账号托管域名中“最长后缀匹配”出实际 Zone（API_DOMAIN）
# 3) 记录 RecordId 到缓存，便于 cleanup 钩子精确删除
# 4) 需要已安装：/usr/local/bin/aliyun、jq、dig（bind-utils/dnsutils）
# 5) 需要已配置 root 的 aliyun profile（默认：certbot）
#    例如：sudo /usr/local/bin/aliyun configure set --profile certbot --access-key-id ... --access-key-secret ... --region cn-hangzhou --language zh

set -euo pipefail

# ---------------- 基本配置（可按需修改） ----------------
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

ALIYUN_BIN="/usr/local/bin/aliyun"                # 阿里云 CLI 绝对路径（建议保持）
JQ_BIN="$(command -v jq || true)"
DIG_BIN="$(command -v dig || true)"

PROFILE="${PROFILE:-certbot}"                      # aliyun CLI 的 profile 名称
TTL="${TTL:-600}"                                  # AliDNS 最小 600
LOG="${LOG:-/var/log/letsencrypt/dns-auth-aliyun.log}"
CACHE_DIR="${CACHE_DIR:-/var/lib/letsencrypt/aliyun-txt-cache}"

# 由 certbot 注入
REQ_DOMAIN="${CERTBOT_DOMAIN:?CERTBOT_DOMAIN missing}"
REQ_VALUE="${CERTBOT_VALIDATION:?CERTBOT_VALIDATION missing}"

NS_QUERIES=("8.8.8.8" "1.1.1.1")                   # 轮询的公共 DNS
WAIT_TRIES="${WAIT_TRIES:-36}"                     # 36 * 5s = 180s
WAIT_INTERVAL="${WAIT_INTERVAL:-5}"

# ---------------- 工具函数 ----------------
log(){ echo "$(date '+%F %T') [AUTH] $*" | tee -a "$LOG"; }
fail(){ log "ERROR: $*"; exit 1; }

ensure_bin(){
  local name="$1" path="$2" hint="$3"
  if [[ -z "$path" || ! -x "$path" ]]; then
    fail "未找到 ${name}（${hint}）。PATH=$PATH"
  fi
}

# ---------------- 预检 ----------------
mkdir -p "$(dirname "$LOG")" "$CACHE_DIR" || true

log "========== DNS AUTH START =========="
log "whoami=$(id -un) uid=$(id -u) HOME=$HOME SHELL=$SHELL"
log "ENV PATH=$PATH"
log "BIN aliyun=$ALIYUN_BIN jq=$JQ_BIN dig=$DIG_BIN"
log "PROFILE=$PROFILE  REQ_DOMAIN=$REQ_DOMAIN"

ensure_bin "aliyun" "$ALIYUN_BIN" "请安装阿里云 CLI 并放入 /usr/local/bin"
ensure_bin "jq"     "$JQ_BIN"     "请安装 jq"
ensure_bin "dig"    "$DIG_BIN"    "请安装 bind-utils/dnsutils（提供 dig）"

if [[ "$TTL" -lt 600 ]]; then
  log "TTL=$TTL 小于 AliDNS 最小值 600，自动提升为 600"
  TTL=600
fi

# 打印 root 的 aliyun 配置（用于确认 profile 存在）
log "aliyun profiles: $("$ALIYUN_BIN" configure list 2>&1 | tr '\n' ' ')"
log "aliyun get --profile $PROFILE: $("$ALIYUN_BIN" configure get --profile "$PROFILE" 2>&1 | tr '\n' ' ')"

# ---------------- 读取账号托管域名列表（不吞错，失败直接终止） ----------------
ACCOUNT_DOMAINS_RAW="$("$ALIYUN_BIN" --profile "$PROFILE" alidns DescribeDomains --PageSize 100)"
log "DescribeDomains raw length=${#ACCOUNT_DOMAINS_RAW}"

ACCOUNT_DOMAINS="$("$JQ_BIN" -r '.Domains.Domain[]?.DomainName' <<<"$ACCOUNT_DOMAINS_RAW" | sort -u)"
log "ACCOUNT_DOMAINS=$(echo "$ACCOUNT_DOMAINS" | tr '\n' ' ')"

if [[ -z "$ACCOUNT_DOMAINS" ]]; then
  echo "$ACCOUNT_DOMAINS_RAW" >> "$LOG"
  fail "当前阿里云账号下未找到托管域名（或解析失败），原始返回已附加到日志"
fi

# ---------------- 最长后缀匹配确定 API_DOMAIN（实际托管 Zone） ----------------
API_DOMAIN=""
BESTLEN=0
while IFS= read -r d; do
  [[ -z "$d" ]] && continue
  if [[ "$REQ_DOMAIN" == "$d" || "$REQ_DOMAIN" == *."$d" ]]; then
    if (( ${#d} > BESTLEN )); then
      API_DOMAIN="$d"
      BESTLEN=${#d}
    fi
  fi
done <<< "$ACCOUNT_DOMAINS"

if [[ -z "$API_DOMAIN" ]]; then
  # 安全兜底（按你的实际根域名修改）
  # 你当前的域名托管在 AliDNS：qinsuda.xyz
  API_DOMAIN="qinsuda.xyz"
  log "未匹配到托管域，使用兜底 API_DOMAIN=$API_DOMAIN"
fi

# 计算 RR：REQ_DOMAIN 恰等于 API_DOMAIN → RR="_acme-challenge"
# 否则去掉后缀，前面加 _acme-challenge.
LEFT="${REQ_DOMAIN%.$API_DOMAIN}"
if [[ "$LEFT" == "$REQ_DOMAIN" ]]; then
  RR="_acme-challenge"
else
  RR="_acme-challenge.$LEFT"
fi

log "确定 API_DOMAIN=$API_DOMAIN  RR=$RR"
log "将写入 TXT: ${RR}.${API_DOMAIN} -> ${REQ_VALUE}"

# ---------------- 删除同名不同值 TXT（避免干扰） ----------------
EXIST_JSON="$("$ALIYUN_BIN" --profile "$PROFILE" alidns DescribeSubDomainRecords \
  --SubDomain "${RR}.${API_DOMAIN}" --Type TXT || true)"

# 删除值不等的旧记录（若存在）
if [[ -n "$EXIST_JSON" ]]; then
  while IFS= read -r rid; do
    [[ -z "$rid" ]] && continue
    val="$("$JQ_BIN" -r ".DomainRecords.Record[] | select(.RecordId==\"$rid\") | .Value" <<<"$EXIST_JSON")"
    if [[ "$val" != "$REQ_VALUE" ]]; then
      log "删除旧TXT: RecordId=$rid Value=$val"
      "$ALIYUN_BIN" --profile "$PROFILE" alidns DeleteDomainRecord --RecordId "$rid" >/dev/null || true
    else
      log "已存在相同值的 TXT（保留）：RecordId=$rid"
    fi
  done < <("$JQ_BIN" -r '.DomainRecords.Record[]? | select(.Type=="TXT") | .RecordId' <<<"$EXIST_JSON")
fi

# ---------------- 添加 TXT ----------------
ADD_JSON="$("$ALIYUN_BIN" --profile "$PROFILE" alidns AddDomainRecord \
  --DomainName "$API_DOMAIN" --RR "$RR" --Type TXT --Value "$REQ_VALUE" --TTL "$TTL" 2>&1 || true)"

REC_ID="$("$JQ_BIN" -r '.RecordId // empty' <<<"$ADD_JSON" 2>/dev/null || true)"
if [[ -z "$REC_ID" || "$REC_ID" == "null" ]]; then
  log "添加 TXT 失败，原始返回：$ADD_JSON"
  fail "AliDNS AddDomainRecord 失败"
fi

log "添加成功：RecordId=$REC_ID"
echo "$REC_ID" > "${CACHE_DIR}/${REQ_DOMAIN}.${REQ_VALUE}.id"

# ---------------- 轮询等待公共 DNS 可见 ----------------
RECORD_FQDN="_acme-challenge.${REQ_DOMAIN}"
log "等待解析生效：$RECORD_FQDN"
FOUND=0
for ns in "${NS_QUERIES[@]}"; do
  for ((i=1; i<=WAIT_TRIES; i++)); do
    got="$("$DIG_BIN" +short TXT "$RECORD_FQDN" @"$ns" 2>/dev/null | tr -d '"')"
    if grep -F -- "$REQ_VALUE" <<<"$got" >/dev/null 2>&1; then
      log "在 $ns 观测到 TXT 生效（耗时 $((i*WAIT_INTERVAL))s）"
      FOUND=1
      break
    fi
    sleep "$WAIT_INTERVAL"
    if [[ $i -eq $WAIT_TRIES ]]; then
      log "WARN: $ns 未观测到 TXT 生效（${WAIT_TRIES}*${WAIT_INTERVAL}s）"
    fi
  done
  [[ $FOUND -eq 1 ]] && break
done

if [[ $FOUND -ne 1 ]]; then
  fail "DNS 记录在等待窗口内未生效，请检查权威 NS、传播时间或递归缓存"
fi

log "========== DNS AUTH SUCCESS =========="
exit 0
