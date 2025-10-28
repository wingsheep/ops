#!/bin/bash
# Let's Encrypt 证书自动化系统安装脚本（整理版）
set -euo pipefail

INSTALL_DIR="/etc/nginx/cert-automation"
LOG_FILE="/var/log/nginx/install.log"
# 仓库根目录（本脚本位于 repo/scripts/install.sh）
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"; }

check_root() {
  if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    echo "错误: 请使用 root 权限运行此脚本" >&2
    exit 1
  fi
}

create_directories() {
  log "创建必要目录..."
  mkdir -p /var/log/nginx /var/backups/letsencrypt
  mkdir -p "$INSTALL_DIR"
  mkdir -p /etc/letsencrypt/renewal-hooks/pre \
           /etc/letsencrypt/renewal-hooks/deploy \
           /etc/letsencrypt/renewal-hooks/post
}

install_system_dependencies() {
  log "安装系统依赖..."
  if command -v yum >/dev/null 2>&1; then
    yum install -y python3 python3-pip certbot jq bind-utils || yum install -y python3 python3-pip certbot jq
  elif command -v apt >/dev/null 2>&1; then
    apt update
    apt install -y python3 python3-pip certbot jq dnsutils
  else
    log "警告: 未识别的系统，跳过系统依赖安装。请确保已安装 python3、pip3、certbot、jq、dig。"
  fi
}

sync_files() {
  log "同步文件到 $INSTALL_DIR..."

  # 脚本与配置
  install -m 0644 "$REPO_ROOT/requirements.txt" "$INSTALL_DIR/"
  install -m 0755 "$REPO_ROOT/scripts/certbot/auto_cert_renewal.sh" "$INSTALL_DIR/"
  install -m 0755 "$REPO_ROOT/scripts/certbot/dns_cert_renewal.sh" "$INSTALL_DIR/"
  install -m 0755 "$REPO_ROOT/scripts/certbot/test_all_config.sh" "$INSTALL_DIR/" || true

  install -m 0755 "$REPO_ROOT/scripts/certbot/hooks/dns/dns_auth_hook.sh" "$INSTALL_DIR/"
  install -m 0755 "$REPO_ROOT/scripts/certbot/hooks/dns/dns_cleanup_hook.sh" "$INSTALL_DIR/"

  install -m 0755 "$REPO_ROOT/scripts/qiniu/upload_cert_to_qiniu.py" "$INSTALL_DIR/"
  install -m 0755 "$REPO_ROOT/scripts/qiniu/verify_qiniu_auth.py" "$INSTALL_DIR/" || true
  install -m 0755 "$REPO_ROOT/scripts/qiniu/test_qiniu_api.py" "$INSTALL_DIR/" || true

  install -m 0644 "$REPO_ROOT/config/qiniu_env.example" "$INSTALL_DIR/"

  # Certbot renewal hooks
  install -m 0755 "$REPO_ROOT/scripts/certbot/hooks/renewal/pre/backup-certs.sh"   /etc/letsencrypt/renewal-hooks/pre/
  install -m 0755 "$REPO_ROOT/scripts/certbot/hooks/renewal/deploy/upload-to-qiniu.sh" /etc/letsencrypt/renewal-hooks/deploy/
  install -m 0755 "$REPO_ROOT/scripts/certbot/hooks/renewal/post/reload-nginx.sh"  /etc/letsencrypt/renewal-hooks/post/
}

install_python_dependencies() {
  log "安装 Python 依赖..."
  pip3 install -r "$INSTALL_DIR/requirements.txt"
}

show_guide() {
  cat <<EOF

🎉 安装完成！

📁 脚本目录: $INSTALL_DIR
🔧 Hooks 目录: /etc/letsencrypt/renewal-hooks/{pre,deploy,post}

下一步：
1) 配置七牛云环境变量
   cd $INSTALL_DIR
   cp qiniu_env.example qiniu_env.sh && vim qiniu_env.sh

2) 准备 DNS 手动验证（Aliyun CLI + hooks）
   - 安装 jq/dig：
     yum:   yum install -y jq bind-utils
     apt:   apt install -y jq dnsutils
   - 安装 aliyun CLI（参考阿里云官方）：
     curl -sS https://aliyuncli.alicdn.com/aliyun-cli-linux-latest-amd64.tgz | tar -xz
     mv aliyun /usr/local/bin/
     aliyun version
   - 配置 root 的 aliyun Profile（本系统默认读取 profile=certbot）：
     aliyun configure set --profile certbot --access-key-id <AK> --access-key-secret <SK> --region cn-hangzhou --language zh

3) 选择验证方式：
   - HTTP 验证：./auto_cert_renewal.sh
   - DNS 验证： ./dns_cert_renewal.sh

常用命令：
  certbot renew --dry-run
  certbot certificates
  tail -f /var/log/nginx/install.log

EOF
}

main() {
  log "========== 开始安装 Let's Encrypt 证书自动化系统 =========="
  check_root
  create_directories
  install_system_dependencies
  sync_files
  install_python_dependencies
  log "安装完成"
  show_guide
}

main "$@"
