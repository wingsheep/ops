# Certbot自动化完整指南

## 🎯 自动化架构

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Crontab       │    │   Certbot        │    │   Hook Scripts  │
│   定时触发      │───▶│   检查/续期      │───▶│   自动处理      │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                        │                        │
         │                        │                        ▼
         │                        │              ┌─────────────────┐
         │                        │              │ 1. Pre Hook     │
         │                        │              │ 2. 续期过程     │
         │                        │              │ 3. Deploy Hook  │
         │                        │              │ 4. Post Hook    │
         │                        │              └─────────────────┘
         │                        │                        │
         │                        │                        ▼
         │                        │              ┌─────────────────┐
         │                        │              │ 上传到七牛云    │
         │                        │              │ 重载nginx       │
         │                        │              │ 发送通知        │
         │                        │              └─────────────────┘
         │                        │
         ▼                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                     完全自动化                                  │
└─────────────────────────────────────────────────────────────────┘
```

## 📋 组件说明

### 1. **Crontab定时任务** ⏰
```bash
# 每天凌晨2点检查证书
0 2 * * * certbot renew --quiet

# 每月1号凌晨3点强制检查（备用）
0 3 1 * * certbot renew --force-renewal
```

**作用**: 主动触发Certbot运行，检查证书是否需要续期

### 2. **Certbot续期检查** 🔍
- Certbot会检查所有证书的到期时间
- 如果距离到期时间少于30天，自动续期
- 使用`--quiet`参数减少输出

### 3. **Hook脚本** 🪝

#### Pre Hook (`/etc/letsencrypt/renewal-hooks/pre/`)
- **执行时机**: 每次Certbot运行前
- **功能**: 备份现有证书
- **脚本**: `backup-certs.sh`

#### Deploy Hook (`/etc/letsencrypt/renewal-hooks/deploy/`)
- **执行时机**: 仅在证书实际续期时
- **功能**: 上传新证书到七牛云CDN
- **脚本**: `upload-to-qiniu.sh`

#### Post Hook (`/etc/letsencrypt/renewal-hooks/post/`)
- **执行时机**: 每次Certbot运行后
- **功能**: 重载nginx配置
- **脚本**: `reload-nginx.sh`

## 🚀 工作流程

### 正常续期流程
```
1. Crontab触发 → certbot renew --quiet
2. Pre Hook → 备份现有证书
3. Certbot检查 → 发现证书需要续期
4. 续期过程 → 获取新证书
5. Deploy Hook → 上传到七牛云 (仅在实际续期时)
6. Post Hook → 重载nginx
7. 完成 → 发送通知日志
```

### 无需续期流程
```
1. Crontab触发 → certbot renew --quiet
2. Pre Hook → 备份现有证书
3. Certbot检查 → 证书还未到期，跳过续期
4. Deploy Hook → 不执行 (因为没有实际续期)
5. Post Hook → 重载nginx (确保配置正确)
6. 完成 → 记录日志
```

## 📊 Hook脚本详情

### Pre Hook - 证书备份
```bash
/etc/letsencrypt/renewal-hooks/pre/backup-certs.sh
```
- 创建时间戳备份文件
- 保留最新5个备份
- 自动清理旧备份

### Deploy Hook - 七牛云上传
```bash
/etc/letsencrypt/renewal-hooks/deploy/upload-to-qiniu.sh
```
- 检查续期的域名是否为`file.qinsuda.xyz`
- 加载七牛云环境变量
- 调用Python脚本上传证书
- 发送成功通知

### Post Hook - 重载nginx
```bash
/etc/letsencrypt/renewal-hooks/post/reload-nginx.sh
```
- 检查nginx配置语法
- 重载nginx服务
- 确保新证书生效

## 📝 日志文件

- `/var/log/nginx/certbot_pre.log` - Pre Hook日志
- `/var/log/nginx/certbot_deploy.log` - Deploy Hook日志  
- `/var/log/nginx/certbot_post.log` - Post Hook日志
- `/etc/nginx/qiniu_cert_upload.log` - 七牛云API日志

## 🔧 测试和验证

### 测试Hook脚本
```bash
# 测试续期（不实际执行）
certbot renew --dry-run

# 手动触发hooks测试
RENEWED_DOMAINS="file.qinsuda.xyz" RENEWED_LINEAGE="/etc/letsencrypt/live/file.qinsuda.xyz" /etc/letsencrypt/renewal-hooks/deploy/upload-to-qiniu.sh
```

### 验证定时任务
```bash
# 查看crontab
crontab -l

# 查看系统日志
tail -f /var/log/cron
```

### 检查证书状态
```bash
# 查看所有证书
certbot certificates

# 检查特定证书
openssl x509 -in /etc/letsencrypt/live/file.qinsuda.xyz/fullchain.pem -noout -dates
```

## ⚡ 优势总结

### 1. **完全自动化**
- 无需人工干预
- 24/7自动监控
- 自动处理续期和上传

### 2. **可靠性**
- 每天检查，确保不遗漏
- 备份机制，防止数据丢失
- 错误处理和日志记录

### 3. **灵活性**
- Hook脚本可扩展
- 支持多域名
- 可添加更多通知方式

### 4. **安全性**
- 环境变量保护密钥
- 脚本权限控制
- 完整的审计日志

## 🎉 最终效果

设置完成后，您完全不需要再关心证书问题：

✅ **证书自动续期** - 距离到期30天时自动续期  
✅ **自动上传CDN** - 新证书自动上传到七牛云  
✅ **自动更新配置** - nginx自动重载新证书  
✅ **完整监控** - 详细日志记录所有操作  
✅ **故障通知** - 出错时记录详细错误信息  

这就是真正的"一次配置，终身受用"！🚀 
