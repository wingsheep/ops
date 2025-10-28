# 快速开始（Getting Started）

🎯 目标：自动续期 Let's Encrypt 证书，并将新证书上传至七牛云 CDN（手动 DNS 验证 + Aliyun CLI）。

## 📁 运行目录结构（安装后）

安装脚本会将必要文件安装到系统目录。安装完成后，运行目录如下：

```
/etc/nginx/cert-automation/
├── requirements.txt                    # Python 依赖说明
├── qiniu_env.example                   # 七牛云环境变量示例
│
├── auto_cert_renewal.sh                # HTTP验证自动续期脚本
├── dns_cert_renewal.sh                 # DNS验证证书获取/续期脚本
├── dns_auth_hook.sh                    # DNS手动验证：认证钩子
├── dns_cleanup_hook.sh                 # DNS手动验证：清理钩子
└── upload_cert_to_qiniu.py             # 七牛云证书上传核心脚本
```

项目文档保存在仓库的 `docs/` 目录（不会安装到系统目录）。

## 🚀 快速开始

### 方法1: 一键安装 (推荐)
```bash
# 在仓库根目录执行
sudo bash scripts/install.sh
```

### 方法2: 手动安装（可选）
安装脚本会自动完成依赖安装与文件部署。若需手动：
1) 安装 certbot、python3/pip3、jq、dig 等依赖；
2) 将仓库中的脚本与示例配置复制到 `/etc/nginx/cert-automation`；
3) 在该目录下 `pip3 install -r requirements.txt`；
4) 参考下文选择验证方式运行脚本。

### 3. 选择验证方式

#### 🌐 域名解析到CDN (推荐：DNS 手动验证 + Aliyun CLI)
```bash
# 1) 安装 Aliyun CLI 与依赖（以 yum 为例）
sudo yum install -y jq bind-utils
curl -sS https://aliyuncli.alicdn.com/aliyun-cli-linux-latest-amd64.tgz | tar -xz
sudo mv aliyun /usr/local/bin/
aliyun version

# 2) 配置 root 的 aliyun profile（脚本默认使用 profile=certbot）
sudo aliyun configure set --profile certbot --access-key-id <AK> --access-key-secret <SK> --region cn-hangzhou --language zh

# 3) 运行脚本（使用手动 hooks）
cd /etc/nginx/cert-automation && ./dns_cert_renewal.sh
```

#### 🏠 域名解析到服务器 (HTTP验证)
```bash
# 直接运行自动化脚本
./auto_cert_renewal.sh
```

## 📚 文档目录

| 文档 | 说明 |
|------|------|
| [USER_GUIDE.md](USER_GUIDE.md) | 用户指南与系统说明 |
| [CERTBOT_HOOKS.md](CERTBOT_HOOKS.md) | Certbot Hooks 说明 |
| [DNS_MANUAL_ALIYUN.md](DNS_MANUAL_ALIYUN.md) | DNS 手动验证（Aliyun CLI）|

## 🎯 解决方案对比

| 场景 | 验证方式 | 脚本 | 自动化程度 |
|------|---------|------|------------|
| 域名解析到服务器 | HTTP验证 | `auto_cert_renewal.sh` | ⭐⭐⭐⭐⭐ 完全自动 |
| 域名解析到CDN | DNS手动验证（Aliyun CLI + hooks） | `dns_cert_renewal.sh` | ⭐⭐⭐ 半自动 |

## 🔧 系统集成

### Certbot Hook配置
系统已自动配置Hook脚本到Certbot：

```bash
/etc/letsencrypt/renewal-hooks/
├── pre/backup-certs.sh         # 续期前备份证书
├── deploy/upload-to-qiniu.sh   # 续期成功后上传到七牛云
└── post/reload-nginx.sh        # 续期后重载nginx
```

### 定时任务配置
```bash
# 查看当前crontab
crontab -l

# 根据验证方式选择：
# HTTP验证: 每天检查
# DNS验证: 每月检查
```

提示：日志位置与日常维护命令见根目录 `README.md`。
## 相关说明

- 故障排除与系统说明：见 `USER_GUIDE.md`
- Hook 细节：见 `CERTBOT_HOOKS.md`
- DNS 手动验证：见 `DNS_MANUAL_ALIYUN.md`
