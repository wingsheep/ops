# 用户指南与系统说明（User Guide）

本系统解决了Let's Encrypt证书3个月过期的问题，实现自动续期并上传到七牛云CDN。

## 功能特性

1. **自动获取Let's Encrypt证书**：首次自动获取，后续自动续期
2. **自动上传到七牛云CDN**：使用七牛云API自动上传并配置证书
3. **自动清理旧证书**：保留最新2个证书，自动删除旧证书
4. **完整日志记录**：详细的操作日志便于排查问题
5. **错误处理和回滚**：出错时自动回滚配置

## 文件说明（安装目录：/etc/nginx/cert-automation）

- `upload_cert_to_qiniu.py` - 核心 Python 脚本，处理证书上传到七牛云
- `auto_cert_renewal.sh` - 自动化 bash 脚本（HTTP 验证续期）
- `dns_cert_renewal.sh` - DNS 验证证书获取/续期脚本（手动 hooks + Aliyun CLI）
- `dns_auth_hook.sh` / `dns_cleanup_hook.sh` - Certbot 手动 DNS 验证 Hooks（依赖 Aliyun CLI）
- `requirements.txt` - Python 依赖
- `qiniu_env.example` - 七牛环境变量示例

## 安装步骤

### 1. 安装依赖

推荐：使用仓库安装脚本（自动安装依赖并部署到系统目录）
```bash
sudo bash scripts/install.sh   # 在仓库根目录执行
```

如需手动：
```bash
# 在安装目录内安装 Python 依赖
pip3 install -r requirements.txt

# 确保 certbot 已安装
# CentOS/RHEL: yum install certbot
# Ubuntu/Debian: apt install certbot
```

并安装用于 DNS 手动验证的依赖（Aliyun CLI + jq + dig）：
```bash
# yum 系统
sudo yum install -y jq bind-utils
curl -sS https://aliyuncli.alicdn.com/aliyun-cli-linux-latest-amd64.tgz | tar -xz
sudo mv aliyun /usr/local/bin/
aliyun version

# 以 root 配置 aliyun profile（默认使用 profile=certbot）
sudo aliyun configure set --profile certbot --access-key-id <AK> --access-key-secret <SK> --region cn-hangzhou --language zh
```

### 2. 配置七牛云密钥

```bash
# 复制环境变量配置文件
cp qiniu_env.example qiniu_env.sh

# 编辑配置文件，填入真实的七牛云密钥
vim qiniu_env.sh

# 加载环境变量
source qiniu_env.sh

# 或者添加到系统环境变量
echo 'export QINIU_ACCESS_KEY="your_key"' >> /etc/environment
echo 'export QINIU_SECRET_KEY="your_secret"' >> /etc/environment
```

### 3. 首次运行

```bash
# 确保file.example.com域名已解析到服务器
# 执行自动化脚本
./auto_cert_renewal.sh
```

### 4. 设置定时任务

```bash
# 编辑crontab
crontab -e

# 添加以下行（每月1号凌晨2点执行）
0 2 1 * * cd /etc/nginx/cert-automation && source qiniu_env.sh && ./auto_cert_renewal.sh
```

## 七牛云API配置

根据[七牛云证书管理API文档](https://developer.qiniu.com/fusion/8593/interface-related-certificate)，本系统支持以下功能：

### 证书操作
- ✅ 上传证书 (`POST /sslcert`)
- ✅ 获取证书列表 (`GET /sslcert`)  
- ✅ 删除证书 (`DELETE /sslcert/<CertID>`)
- ✅ 更新域名证书配置

### 错误处理
系统会处理以下七牛云API错误：
- 400500: 超过用户绑定证书最大额度
- 404906: https证书解码失败
- 400323: 验证https证书链失败
- 400322: https证书有效期太短
- 400329: https证书过期

## 使用流程

### 自动化流程
1. **检查nginx配置** - 确保配置文件语法正确
2. **获取/续期证书** - 使用certbot获取或续期Let's Encrypt证书  
3. **启用HTTPS配置** - 首次运行时自动启用nginx HTTPS配置
4. **上传到七牛云** - 使用API上传证书并绑定到CDN域名
5. **清理旧证书** - 自动删除七牛云中的旧证书

### 手动操作
```bash
# 只更新证书到七牛云（证书已存在）
python3 upload_cert_to_qiniu.py

# 只获取Let's Encrypt证书
certbot certonly --webroot -w /usr/share/nginx/html -d file.example.com

# 检查证书有效期
openssl x509 -in /etc/letsencrypt/live/file.example.com/fullchain.pem -noout -dates
```

## 日志和监控

### 日志文件
- `/var/log/nginx/cert_renewal.log` - 主要操作日志
- `/etc/nginx/qiniu_cert_upload.log` - 七牛云API调用日志

### 监控命令
```bash
# 查看最新日志
tail -f /var/log/nginx/cert_renewal.log

# 检查证书状态
certbot certificates

# 测试证书续期（不实际执行）
certbot renew --dry-run
```

## 故障排除

### 常见问题

1. **域名解析问题**
   ```bash
   # 检查域名解析
   nslookup file.example.com
   ```

2. **nginx配置问题**
   ```bash
   # 检查配置语法
   nginx -t
   
   # 查看错误日志
   tail /var/log/nginx/error.log
   ```

3. **Let's Encrypt验证失败**
   ```bash
   # 检查webroot目录权限
   ls -la /usr/share/nginx/html/.well-known/
   
   # 手动测试验证
   certbot certonly --webroot -w /usr/share/nginx/html -d file.example.com --dry-run
   ```

4. **七牛云API调用失败**
   ```bash
   # 检查环境变量
   echo $QINIU_ACCESS_KEY
   echo $QINIU_SECRET_KEY
   
   # 查看详细日志
   tail /etc/nginx/qiniu_cert_upload.log
   ```

## 安全建议

1. **保护密钥文件**
   ```bash
   chmod 600 qiniu_env.sh
   ```

2. **限制脚本权限**
   ```bash
   chmod 700 auto_cert_renewal.sh
   chmod 700 upload_cert_to_qiniu.py
   ```

3. **定期备份证书**
   ```bash
   # 备份Let's Encrypt证书
   tar -czf letsencrypt_backup_$(date +%Y%m%d).tar.gz /etc/letsencrypt/
   ```

## 技术架构

### nginx配置
- HTTP 服务器：处理 Let's Encrypt 验证请求
- HTTPS 服务器：证书获取后自动启用

### Python脚本
- 使用七牛云官方API进行证书管理
- 支持QBox认证方式
- 完整的错误处理和日志记录

### 自动化脚本
- bash脚本统一管理整个流程
- 支持首次部署和定期续期
- 出错时自动回滚配置

这个系统完全解决了Let's Encrypt证书手动续期的问题，实现了真正的自动化！ 
