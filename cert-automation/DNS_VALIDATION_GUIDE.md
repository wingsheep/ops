# DNS验证证书获取指南

## 🎯 问题背景

当域名解析到CDN（如七牛云）时，HTTP验证会失败，因为验证请求被发送到CDN而不是原服务器。此时需要使用DNS验证方式。

## 🚀 解决方案

### 方案1: 自动DNS验证 (推荐)

#### 1.1 阿里云DNS自动验证
```bash
# 安装阿里云DNS插件
pip3 install certbot-dns-aliyun

# 配置阿里云API密钥
cp aliyun-credentials.ini.example aliyun-credentials.ini
vim aliyun-credentials.ini  # 填入真实密钥
chmod 600 aliyun-credentials.ini

# 自动获取证书
certbot certonly \
    --dns-aliyun \
    --dns-aliyun-credentials /etc/nginx/aliyun-credentials.ini \
    --email  \
    --agree-tos \
    --non-interactive \
    -d file.qinsuda.xyz
```

#### 1.2 Cloudflare DNS自动验证
```bash
# 安装Cloudflare DNS插件
pip3 install certbot-dns-cloudflare

# 配置Cloudflare API
echo "dns_cloudflare_api_token = your_api_token" > cloudflare-credentials.ini
chmod 600 cloudflare-credentials.ini

# 自动获取证书
certbot certonly \
    --dns-cloudflare \
    --dns-cloudflare-credentials /etc/nginx/cloudflare-credentials.ini \
    --email  \
    --agree-tos \
    --non-interactive \
    -d file.qinsuda.xyz
```

### 方案2: 手动DNS验证

```bash
# 使用DNS验证脚本
./dns_cert_renewal.sh

# 或直接使用certbot手动模式
certbot certonly \
    --manual \
    --preferred-challenges=dns \
    --email  \
    --agree-tos \
    --manual-public-ip-logging-ok \
    -d file.qinsuda.xyz
```

## 📋 DNS验证流程

### 自动验证流程
```
1. Certbot调用DNS API
2. 自动添加TXT记录: _acme-challenge.file.qinsuda.xyz
3. Let's Encrypt验证DNS记录
4. 自动删除临时TXT记录
5. 获取证书成功
6. 触发Deploy Hook上传到七牛云
```

### 手动验证流程
```
1. Certbot生成验证内容
2. 显示需要手动添加的DNS记录
3. 用户手动添加TXT记录
4. 等待DNS记录生效
5. Let's Encrypt验证DNS记录
6. 获取证书成功
7. 提醒用户删除临时记录
```

## 🔧 具体操作步骤

### 首次获取证书

1. **准备DNS API密钥** (推荐自动方式)
   ```bash
   # 阿里云: 控制台 -> 访问控制 -> 用户管理 -> AccessKey
   # Cloudflare: 控制台 -> My Profile -> API Tokens
   ```

2. **配置API密钥文件**
   ```bash
   cp aliyun-credentials.ini.example aliyun-credentials.ini
   vim aliyun-credentials.ini  # 填入真实密钥
   chmod 600 aliyun-credentials.ini
   ```

3. **执行DNS验证脚本**
   ```bash
   ./dns_cert_renewal.sh
   ```

4. **验证证书获取成功**
   ```bash
   certbot certificates
   ls -la /etc/letsencrypt/live/file.qinsuda.xyz/
   ```

### 自动续期配置

crontab已配置为使用DNS验证：
```bash
# 每月1号凌晨2点检查
0 2 1 * * certbot renew --preferred-challenges=dns --quiet

# 每3个月强制检查
0 3 1 */3 * certbot renew --preferred-challenges=dns --force-renewal
```

## 🎯 验证方式对比

| 验证方式 | 优点 | 缺点 | 适用场景 |
|---------|------|------|----------|
| HTTP验证 | 简单，无需DNS API | 域名必须解析到服务器 | 域名直接解析到服务器 |
| DNS自动验证 | 完全自动化，支持CDN | 需要DNS服务商API | 域名解析到CDN，有API权限 |
| DNS手动验证 | 不需要API，支持CDN | 需要手动操作 | 域名解析到CDN，无API权限 |

## 📝 注意事项

### 1. DNS记录生效时间
- 通常需要1-10分钟
- 某些DNS服务商可能需要更长时间
- 建议在DNS记录添加后等待5分钟再继续

### 2. API权限要求
- **阿里云**: 需要DNS解析权限
- **Cloudflare**: 需要Zone:DNS:Edit权限

### 3. 安全建议
```bash
# 保护API密钥文件
chmod 600 /etc/nginx/*-credentials.ini

# 使用子账号和最小权限
# 不要使用主账号的AccessKey
```

### 4. 故障排除

#### DNS记录不生效
```bash
# 检查DNS记录
dig +short TXT "_acme-challenge.file.qinsuda.xyz"

# 使用不同DNS服务器查询
dig @8.8.8.8 +short TXT "_acme-challenge.file.qinsuda.xyz"
```

#### API权限错误
```bash
# 检查API密钥权限
# 确保有DNS解析的读写权限
```

#### 证书获取失败
```bash
# 查看详细日志
certbot certonly --dns-aliyun --dry-run -v

# 检查防火墙和网络连接
curl -I https://acme-v02.api.letsencrypt.org/directory
```

## 🎉 成功后的自动化流程

一旦配置成功，整个流程将完全自动化：

1. ✅ **定时检查**: 每月自动检查证书到期
2. ✅ **自动续期**: 使用DNS验证自动续期
3. ✅ **自动上传**: Deploy Hook自动上传新证书到七牛云
4. ✅ **自动配置**: 自动更新nginx配置
5. ✅ **完整日志**: 所有操作都有详细日志记录

这样就完全解决了域名解析到CDN时的证书续期问题！🚀 
