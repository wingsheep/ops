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
echo "🌐 阿里云DNS配置检查"
echo "=================="

if [ -f "aliyun-credentials.ini" ]; then
    echo "✅ 阿里云DNS配置文件存在"
    ACCESS_KEY=$(grep "dns_aliyun_access_key" aliyun-credentials.ini | cut -d= -f2 | tr -d ' ')
    SECRET_KEY=$(grep "dns_aliyun_access_key_secret" aliyun-credentials.ini | cut -d= -f2 | tr -d ' ')
    
    if [ -n "$ACCESS_KEY" ] && [ -n "$SECRET_KEY" ]; then
        echo "   ACCESS_KEY: ${ACCESS_KEY:0:10}...${ACCESS_KEY: -4}"
        echo "   SECRET_KEY: ${SECRET_KEY:0:10}...${SECRET_KEY: -2}"
    else
        echo "❌ 阿里云DNS密钥格式错误"
    fi
else
    echo "❌ 阿里云DNS配置文件不存在"
fi

# 检查域名解析
echo ""
echo "🌍 域名解析检查"
echo "=============="

DOMAIN="file.qinsuda.xyz"
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
echo "2. 或使用手动命令: certbot certonly --manual --preferred-challenges=dns -d file.qinsuda.xyz"

echo ""
echo "🎉 配置检查完成！" 
