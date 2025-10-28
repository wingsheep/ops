# DNS验证证书获取指南

## 🎯 问题背景

当域名解析到CDN（如七牛云）时，HTTP验证会失败，因为验证请求被发送到CDN而不是原服务器。此时需要使用DNS验证方式。

## 🚀 解决方案（推荐：手动 DNS 验证 + Aliyun CLI）

```bash
# 使用DNS验证脚本（安装目录中）
cd /etc/nginx/cert-automation && ./dns_cert_renewal.sh

# 或直接使用 certbot 手动模式
certbot certonly \
    --manual \
    --preferred-challenges=dns \
    --email 1306750238@qq.com \
    --agree-tos \
    --manual-public-ip-logging-ok \
    -d file.qinsuda.xyz
```

## 📋 DNS验证流程

### 验证流程（手动）
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

### 首次获取证书（使用 Aliyun CLI 自动写入/清理 TXT）

1. 安装依赖（以 yum 为例）：
   ```bash
   sudo yum install -y jq bind-utils
   curl -sS https://aliyuncli.alicdn.com/aliyun-cli-linux-latest-amd64.tgz | tar -xz
   sudo mv aliyun /usr/local/bin/
   aliyun version
   ```

2. 配置 root 的 Aliyun Profile（脚本默认读取 profile=certbot）：
   ```bash
   sudo aliyun configure set --profile certbot \
     --access-key-id <AK> --access-key-secret <SK> \
     --region cn-hangzhou --language zh
   ```

3. 执行 DNS 验证脚本（手动 hooks 模式）：
   ```bash
   ./dns_cert_renewal.sh
   ```

4. 验证证书获取成功：
   ```bash
   certbot certificates
   ls -la /etc/letsencrypt/live/file.qinsuda.xyz/
   ```

### 自动续期配置

crontab 配置示例：
```bash
# 每天凌晨2点检查续期（推荐）
0 2 * * * certbot renew --quiet

# 若全站采用 DNS 验证，也可显式指定参数（可选）：
0 2 * * * certbot renew --preferred-challenges=dns --quiet
```

## 🎯 验证方式对比

| 验证方式 | 优点 | 缺点 | 适用场景 |
|---------|------|------|----------|
| HTTP验证 | 简单 | 域名必须解析到服务器 | 域名直接解析到服务器 |
| DNS手动验证（Aliyun CLI） | 支持CDN、自动写入与清理TXT、无需 certbot 插件 | 需安装并配置 Aliyun CLI | 域名解析到CDN |

## 📝 注意事项

### 1. DNS记录生效时间
- 通常需要1-10分钟
- 某些DNS服务商可能需要更长时间
- 建议在DNS记录添加后等待5分钟再继续

### 2. 权限要求（Aliyun）
- 需具备 AliDNS 解析读写权限

### 3. 安全建议
```bash
# 使用子账号与最小权限策略
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

#### Aliyun CLI 权限错误
```bash
# 检查 profile 与权限
aliyun configure list
aliyun --profile certbot alidns DescribeDomains --PageSize 1
```

#### 证书获取失败
```bash
# 查看详细日志
certbot certonly --manual --preferred-challenges=dns -d file.qinsuda.xyz --dry-run -v

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
