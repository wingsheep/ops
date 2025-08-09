# Let's Encrypt证书自动化管理系统

🎯 **完整解决Let's Encrypt证书3个月过期问题，支持自动续期并上传到七牛云CDN**

## 📁 项目结构

```
/etc/nginx/cert-automation/
├── README.md                           # 📖 项目主文档
├── install.sh                          # 🚀 一键安装脚本
├── requirements.txt                    # 🔧 Python依赖包
├── qiniu_env.example                   # 🔑 七牛云环境变量示例
├── aliyun-credentials.ini.example      # 🔑 阿里云DNS API配置示例
│
├── 🤖 自动化脚本
│   ├── upload_cert_to_qiniu.py         # 📤 七牛云证书上传核心脚本
│   ├── auto_cert_renewal.sh            # 🔄 HTTP验证自动续期脚本
│   ├── dns_cert_renewal.sh             # 🌐 DNS验证证书获取脚本
│   ├── dns_auth_hook.sh                # 🔗 DNS验证认证钩子
│   └── dns_cleanup_hook.sh             # 🧹 DNS验证清理钩子
│
└── 📚 说明文档
    ├── README_auto_cert.md             # 📋 自动化系统详细说明
    ├── certbot_automation_guide.md     # 🎯 Certbot Hook完整指南
    └── DNS_VALIDATION_GUIDE.md         # 🌐 DNS验证完整指南
```

## 🚀 快速开始

### 方法1: 一键安装 (推荐)
```bash
cd /etc/nginx/cert-automation
./install.sh
```

### 方法2: 手动安装
```bash
# 1. 安装依赖
pip3 install -r requirements.txt

# 2. 配置七牛云密钥
cp qiniu_env.example qiniu_env.sh
vim qiniu_env.sh  # 填入真实密钥
source qiniu_env.sh

# 3. 选择验证方式
```

### 3. 选择验证方式

#### 🌐 域名解析到CDN (推荐DNS验证)
```bash
# 配置DNS API (可选，用于自动验证)
cp aliyun-credentials.ini.example aliyun-credentials.ini
vim aliyun-credentials.ini  # 填入DNS API密钥

# 获取证书
./dns_cert_renewal.sh
```

#### 🏠 域名解析到服务器 (HTTP验证)
```bash
# 直接运行自动化脚本
./auto_cert_renewal.sh
```

## 📚 详细文档

| 文档 | 说明 | 适用场景 |
|------|------|----------|
| [README_auto_cert.md](README_auto_cert.md) | 完整自动化系统说明 | 了解整体架构和功能 |
| [certbot_automation_guide.md](certbot_automation_guide.md) | Certbot Hook完整指南 | 理解Hook机制和自动化流程 |
| [DNS_VALIDATION_GUIDE.md](DNS_VALIDATION_GUIDE.md) | DNS验证完整指南 | 域名解析到CDN的场景 |

## 🎯 解决方案对比

| 场景 | 验证方式 | 脚本 | 自动化程度 |
|------|---------|------|------------|
| 域名解析到服务器 | HTTP验证 | `auto_cert_renewal.sh` | ⭐⭐⭐⭐⭐ 完全自动 |
| 域名解析到CDN + DNS API | DNS自动验证 | `dns_cert_renewal.sh` | ⭐⭐⭐⭐⭐ 完全自动 |
| 域名解析到CDN + 无API | DNS手动验证 | `dns_cert_renewal.sh` | ⭐⭐⭐ 半自动 |

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

## 📝 日志文件

```bash
/var/log/nginx/
├── install.log             # 安装日志
├── cert_renewal.log        # 主要续期日志
├── certbot_pre.log         # Pre Hook日志
├── certbot_deploy.log      # Deploy Hook日志
├── certbot_post.log        # Post Hook日志
├── dns_cert_renewal.log    # DNS验证日志
└── qiniu_cert_upload.log   # 七牛云上传日志
```

## 🛠️ 维护命令

```bash
# 检查证书状态
certbot certificates

# 测试续期 (不实际执行)
certbot renew --dry-run

# 测试DNS验证 (不实际执行)
certbot renew --preferred-challenges=dns --dry-run

# 查看最新日志
tail -f /var/log/nginx/cert_renewal.log

# 手动上传证书到七牛云
python3 upload_cert_to_qiniu.py

# 检查nginx配置
nginx -t
```

## 🎉 功能特性

- ✅ **完全自动化**: 一次配置，终身受用
- ✅ **双重验证**: 支持HTTP和DNS验证方式  
- ✅ **智能检测**: 自动检测域名解析情况
- ✅ **CDN支持**: 完美支持七牛云CDN
- ✅ **安全可靠**: 完整的备份和回滚机制
- ✅ **详细日志**: 所有操作都有详细记录
- ✅ **错误处理**: 完善的错误处理和通知
- ✅ **扩展性强**: 支持多种DNS服务商
- ✅ **一键安装**: 简化部署流程

## 🆘 故障排除

1. **证书获取失败**: 查看 `DNS_VALIDATION_GUIDE.md`
2. **上传七牛云失败**: 检查环境变量和网络连接
3. **nginx配置问题**: 运行 `nginx -t` 检查语法
4. **Hook脚本问题**: 查看对应的日志文件
5. **安装问题**: 查看 `/var/log/nginx/install.log`

## 📞 技术支持

- 📖 查看详细文档了解具体配置
- 📝 检查日志文件排查问题
- 🔧 使用测试命令验证配置
- 🚀 运行 `./install.sh` 重新安装

## 🔄 更新说明

### v2.0 (当前版本)
- ✅ 支持DNS验证，解决CDN场景问题
- ✅ 重构代码，统一目录管理
- ✅ 添加一键安装脚本
- ✅ 完善文档和故障排除指南

### v1.0
- ✅ 基础HTTP验证自动化
- ✅ 七牛云证书自动上传
- ✅ Certbot Hook集成

---

**🎯 这个系统完全解决了Let's Encrypt证书手动续期的问题，实现了真正的自动化！** 
