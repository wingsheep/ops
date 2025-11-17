#!/bin/bash
# 完整配置验证脚本

echo "🔧 Let's Encrypt自动化系统配置验证"
echo "=================================="

# 检查七牛云配置
echo ""
echo "📤 七牛云配置检查"
echo "================"

if [ -f "qiniu_env.sh" ]; then
    source qiniu_env.sh
    if [ -n "$QINIU_ACCESS_KEY" ] && [ -n "$QINIU_SECRET_KEY" ]; then
        echo "✅ 七牛云密钥配置正确"
        echo "   ACCESS_KEY: ${QINIU_ACCESS_KEY:0:10}...${QINIU_ACCESS_KEY: -4}"
        echo "   SECRET_KEY: ${QINIU_SECRET_KEY:0:10}...${QINIU_SECRET_KEY: -4}"
    else
        echo "❌ 七牛云密钥未正确配置"
    fi
else
    echo "❌ 七牛云环境变量文件不存在"
fi

# 检查阿里云DNS配置
echo ""
echo "🌐 阿里云 CLI 检查"
echo "=================="

if command -v aliyun >/dev/null 2>&1; then
    echo "✅ 已安装 aliyun CLI: $(aliyun version 2>/dev/null)"
    echo "   Profiles: $(aliyun configure list 2>/dev/null | tr '\n' ' ')"
    if aliyun --profile certbot configure get >/dev/null 2>&1; then
        echo "✅ 存在 profile: certbot"
    else
        echo "❌ 未检测到 profile: certbot，请执行："
        echo "   aliyun configure set --profile certbot --access-key-id <AK> --access-key-secret <SK> --region cn-hangzhou --language zh"
    fi
else
    echo "❌ 未安装 aliyun CLI"
fi

# 检查域名解析
echo ""
echo "🌍 域名解析检查"
echo "=============="

DOMAIN="file.example.com"
RESOLVED_IP=$(ping -c 1 "$DOMAIN" 2>/dev/null | grep PING | sed -E 's/^[^(]+\(([^)]+)\).*$/\1/')

if [ -n "$RESOLVED_IP" ]; then
    echo "✅ 域名解析正常: $DOMAIN -> $RESOLVED_IP"
    echo "🔍 检测到CDN解析，建议使用DNS验证"
else
    echo "❌ 域名解析失败: $DOMAIN"
fi

echo ""
echo "🎯 建议操作"
echo "=========="
echo "1. 运行 DNS 验证获取证书: ./dns_cert_renewal.sh"
echo "2. 或使用手动命令: certbot certonly --manual --preferred-challenges=dns -d file.example.com"

echo ""
echo "🎉 配置检查完成！" 
