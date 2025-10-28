# Certbot 自动续期 + 七牛云证书上传（整理版）

本项目用于自动续期 Let's Encrypt 证书，并在续期成功后自动把证书上传到七牛云 CDN。已对原有文件进行分层整理：配置文件、七牛脚本、Certbot 脚本与 hooks、说明文档。

## 项目结构

```
.
├── requirements.txt                  # Python 依赖
├── config/                            # 配置示例
│   ├── qiniu_env.example
│   └── （已移除阿里云插件示例，改用 Aliyun CLI 手动 DNS 验证）
├── docs/                              # 说明文档
│   ├── GETTING_STARTED.md             # 快速开始（替代 OVERVIEW）
│   ├── USER_GUIDE.md                  # 用户指南与系统说明
│   ├── CERTBOT_HOOKS.md               # Certbot Hooks 说明
│   └── DNS_MANUAL_ALIYUN.md           # DNS 手动验证（Aliyun CLI）
└── scripts/
    ├── install.sh                     # 一键安装到系统目录
    ├── certbot/                       # Certbot 相关脚本
    │   ├── auto_cert_renewal.sh       # HTTP 验证自动续期
    │   ├── dns_cert_renewal.sh        # DNS 验证获取/续期
    │   ├── test_all_config.sh         # 配置检查
    │   └── hooks/
    │       ├── dns/                   # Certbot 手动 DNS 验证 hooks
    │       │   ├── dns_auth_hook.sh
    │       │   └── dns_cleanup_hook.sh
    │       └── renewal/               # Certbot 标准 renewal hooks（系统安装路径）
    │           ├── pre/backup-certs.sh
    │           ├── deploy/upload-to-qiniu.sh
    │           └── post/reload-nginx.sh
    └── qiniu/                         # 七牛云相关脚本
        ├── upload_cert_to_qiniu.py    # 上传证书
        ├── verify_qiniu_auth.py       # QBox 签名验证
        └── test_qiniu_api.py          # API 权限自测
```

安装后运行目录：`/etc/nginx/cert-automation`，Certbot hooks 安装到 `/etc/letsencrypt/renewal-hooks/{pre,deploy,post}`。

## 快速开始

1) 安装（需 root）：
```bash
sudo bash scripts/install.sh
```

2) 配置密钥：
```bash
cd /etc/nginx/cert-automation
cp qiniu_env.example qiniu_env.sh && vim qiniu_env.sh
# 可选（DNS 自动验证）：
# DNS 验证改为 Aliyun CLI + 手动 hooks，无需 certbot-dns-aliyun 插件
```

3) 选择验证方式：
- 域名直连服务器（HTTP 验证）：`/etc/nginx/cert-automation/auto_cert_renewal.sh`
- 域名走 CDN（DNS 验证）：`/etc/nginx/cert-automation/dns_cert_renewal.sh`

4) 验证：
```bash
certbot renew --dry-run
```

## 一键安装 Aliyun CLI（yum/apt）

以下命令用于安装 DNS 手动验证所需的依赖（Aliyun CLI + jq + dig），并配置默认 profile（certbot）。

```bash
# RHEL/CentOS（yum）
sudo yum install -y epel-release jq bind-utils && \
curl -sS https://aliyuncli.alicdn.com/aliyun-cli-linux-latest-amd64.tgz | tar -xz && \
sudo mv aliyun /usr/local/bin/ && aliyun version && \
sudo aliyun configure set --profile certbot \
  --access-key-id <AK> --access-key-secret <SK> \
  --region cn-hangzhou --language zh

# Debian/Ubuntu（apt）
sudo apt update && sudo apt install -y jq dnsutils && \
curl -sS https://aliyuncli.alicdn.com/aliyun-cli-linux-latest-amd64.tgz | tar -xz && \
sudo mv aliyun /usr/local/bin/ && aliyun version && \
sudo aliyun configure set --profile certbot \
  --access-key-id <AK> --access-key-secret <SK> \
  --region cn-hangzhou --language zh
```

注意：请将 `<AK>/<SK>` 替换为具有 AliDNS 解析权限的子账号密钥。

## 日志位置
- 安装：`/var/log/nginx/install.log`
- 续期：`/var/log/nginx/cert_renewal.log`
- DNS 验证：`/var/log/nginx/dns_cert_renewal.log`
- Hook：
  - Pre：`/var/log/nginx/certbot_pre.log`
  - Deploy：`/var/log/nginx/certbot_deploy.log`
  - Post：`/var/log/nginx/certbot_post.log`
- 七牛上传：`/etc/nginx/qiniu_cert_upload.log`

## 日常维护常用命令

```bash
# 查看所有证书
certbot certificates

# 预演续期（不改动实际证书）
certbot renew --dry-run

# 检查指定域名证书到期时间
DOMAIN=file.qinsuda.xyz
openssl x509 -in /etc/letsencrypt/live/$DOMAIN/fullchain.pem -noout -dates

# 查看最新日志
tail -f /var/log/nginx/cert_renewal.log
tail -f /etc/nginx/qiniu_cert_upload.log
tail -f /var/log/nginx/certbot_deploy.log

# 手动触发一次七牛证书上传（证书已更新）
cd /etc/nginx/cert-automation && source qiniu_env.sh && python3 upload_cert_to_qiniu.py

# 校验并重载 nginx 配置
nginx -t && sudo systemctl reload nginx

# 检查 Aliyun CLI 配置与权限
aliyun configure list
aliyun --profile certbot alidns DescribeDomains --PageSize 1

# 检查 DNS TXT 是否生效
dig +short TXT _acme-challenge.$DOMAIN
```

## 说明
- 仅整理仓库目录，运行时路径保持为 `/etc/nginx/cert-automation`，避免影响已部署环境。
- 修正了 `scripts/certbot/auto_cert_renewal.sh` 中的安装目录变量，默认从 `qiniu_env.sh` 加载密钥。
- 详细指引见 `docs/`。
