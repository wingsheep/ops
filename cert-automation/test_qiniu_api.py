#!/usr/bin/env python3
"""
七牛云API权限测试脚本
测试不同的API端点来确认密钥权限
"""

import os
import requests
import json
import hmac
import hashlib
import base64
from urllib.parse import urlparse

# 七牛云配置
QINIU_ACCESS_KEY = os.getenv("QINIU_ACCESS_KEY")
QINIU_SECRET_KEY = os.getenv("QINIU_SECRET_KEY")

def generate_qbox_token(access_key, secret_key, method, url, body=None):
    """生成QBox认证token"""
    parsed_url = urlparse(url)
    path_query = parsed_url.path
    if parsed_url.query:
        path_query += '?' + parsed_url.query
    
    # 构建待签名字符串
    auth_str = f"{method} {path_query}\nHost: {parsed_url.netloc}"
    if body:
        auth_str += f"\nContent-Type: application/json\n\n{body}"
    else:
        auth_str += "\n\n"
    
    # 生成签名
    signature = hmac.new(
        secret_key.encode('utf-8'),
        auth_str.encode('utf-8'),
        hashlib.sha1
    ).digest()
    encoded_sign = base64.urlsafe_b64encode(signature).decode('utf-8')
    
    return f"QBox {access_key}:{encoded_sign}"

def test_api_endpoint(name, method, url, body=None):
    """测试API端点"""
    print(f"\n🔍 测试 {name}")
    print(f"   URL: {url}")
    print(f"   方法: {method}")
    
    try:
        token = generate_qbox_token(QINIU_ACCESS_KEY, QINIU_SECRET_KEY, method, url, body)
        headers = {
            "Authorization": token
        }
        
        if body:
            headers["Content-Type"] = "application/json"
            response = requests.request(method, url, data=body, headers=headers, timeout=10)
        else:
            response = requests.request(method, url, headers=headers, timeout=10)
        
        print(f"   状态码: {response.status_code}")
        print(f"   响应: {response.text[:200]}...")
        
        if response.status_code == 401:
            print("   ❌ 认证失败 - 可能是密钥权限不足")
        elif response.status_code == 200:
            print("   ✅ 认证成功")
        elif response.status_code == 404:
            print("   ⚠️  资源不存在但认证通过")
        else:
            print(f"   ⚠️  其他状态码: {response.status_code}")
            
    except Exception as e:
        print(f"   ❌ 请求异常: {str(e)}")

def main():
    if not QINIU_ACCESS_KEY or not QINIU_SECRET_KEY:
        print("❌ 未找到七牛云环境变量")
        return
    
    print("🔧 七牛云API权限测试")
    print("===================")
    print(f"ACCESS_KEY: {QINIU_ACCESS_KEY[:10]}...{QINIU_ACCESS_KEY[-4:]}")
    print(f"SECRET_KEY: {QINIU_SECRET_KEY[:10]}...{QINIU_SECRET_KEY[-4:]}")
    
    # 测试1: 基础存储API（应该有权限）
    test_api_endpoint(
        "对象存储 - Bucket列表", 
        "GET", 
        "https://rs.qiniu.com/buckets"
    )
    
    # 测试2: CDN API - 域名列表
    test_api_endpoint(
        "CDN - 域名列表", 
        "GET", 
        "https://api.qiniu.com/domain"
    )
    
    # 测试3: SSL证书列表
    test_api_endpoint(
        "SSL证书 - 证书列表", 
        "GET", 
        "https://api.qiniu.com/sslcert"
    )
    
    # 测试4: 尝试上传一个测试证书（最小化数据）
    test_data = {
        "name": "test-cert-validation",
        "common_name": "test.example.com",
        "pri": "test-private-key",
        "ca": "test-certificate"
    }
    test_body = json.dumps(test_data)
    
    test_api_endpoint(
        "SSL证书 - 证书上传（测试数据）", 
        "POST", 
        "https://api.qiniu.com/sslcert",
        test_body
    )
    
    print("\n🎯 测试完成")
    print("如果SSL证书API返回401，说明当前密钥没有CDN管理权限")
    print("请在七牛云控制台检查:")
    print("1. 密钥是否有CDN服务权限")
    print("2. 是否开通了CDN服务")
    print("3. 是否需要子账号权限设置")

if __name__ == "__main__":
    main() 
