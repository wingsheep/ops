#!/usr/bin/env python3
"""
验证七牛云管理凭证算法
按照官方文档 https://developer.qiniu.com/kodo/6671/historical-document-management-certificate
"""

import os
import hmac
import hashlib
import base64
import requests
import json

# 七牛云配置
QINIU_ACCESS_KEY = os.getenv("QINIU_ACCESS_KEY")
QINIU_SECRET_KEY = os.getenv("QINIU_SECRET_KEY")

def test_official_example():
    """测试官方文档示例"""
    print("🧪 测试官方文档示例")
    print("==================")
    
    # 官方示例参数
    access_key = "MY_ACCESS_KEY"
    secret_key = "MY_SECRET_KEY"
    url = "http://rs.qiniu.com/move/bmV3ZG9jczpmaW5kX21hbi50eHQ=/bmV3ZG9jczpmaW5kLm1hbi50eHQ="
    
    # 按照官方算法
    # 1. 生成待签名的原始字符串
    signing_str = "/move/bmV3ZG9jczpmaW5kX21hbi50eHQ=/bmV3ZG9jczpmaW5kLm1hbi50eHQ=\n"
    
    # 2. 使用SecretKey计算HMAC-SHA1签名
    sign = hmac.new(
        secret_key.encode('utf-8'),
        signing_str.encode('utf-8'),
        hashlib.sha1
    ).digest()
    
    # 3. 对签名进行URL安全的Base64编码
    encoded_sign = base64.urlsafe_b64encode(sign).decode('utf-8')
    
    # 4. 将AccessKey和encodedSign用:连接
    access_token = f"{access_key}:{encoded_sign}"
    
    print(f"待签名字符串: {repr(signing_str)}")
    print(f"签名结果(hex): {sign.hex()}")
    print(f"编码后签名: {encoded_sign}")
    print(f"最终凭证: {access_token}")
    
    # 官方文档预期结果
    expected_sign_hex = "157b18874c0a1d83c4b0802074f0fd39f8e47843"
    expected_encoded = "FXsYh0wKHYPEsIAgdPD9OfjkeEM="
    expected_token = "MY_ACCESS_KEY:FXsYh0wKHYPEsIAgdPD9OfjkeEM="
    
    print(f"\n期望签名(hex): {expected_sign_hex}")
    print(f"期望编码签名: {expected_encoded}")
    print(f"期望最终凭证: {expected_token}")
    
    print(f"\n✅ 签名匹配: {sign.hex() == expected_sign_hex}")
    print(f"✅ 编码匹配: {encoded_sign == expected_encoded}")
    print(f"✅ 凭证匹配: {access_token == expected_token}")

def generate_management_token(method, url, body=None):
    """生成管理凭证 - 严格按照官方文档"""
    from urllib.parse import urlparse
    
    parsed_url = urlparse(url)
    path_query = parsed_url.path
    if parsed_url.query:
        path_query += '?' + parsed_url.query
    
    # 构建待签名字符串 - 官方格式
    if body:
        signing_str = f"{path_query}\n{body}"
    else:
        signing_str = f"{path_query}\n"
    
    print(f"待签名字符串: {repr(signing_str)}")
    
    # 计算HMAC-SHA1签名
    sign = hmac.new(
        QINIU_SECRET_KEY.encode('utf-8'),
        signing_str.encode('utf-8'),
        hashlib.sha1
    ).digest()
    
    # URL安全的Base64编码
    encoded_sign = base64.urlsafe_b64encode(sign).decode('utf-8')
    
    # 生成最终token
    access_token = f"{QINIU_ACCESS_KEY}:{encoded_sign}"
    
    print(f"生成的签名: {encoded_sign}")
    print(f"管理凭证: QBox {access_token}")
    
    return f"QBox {access_token}"

def test_cert_upload():
    """测试证书上传的token生成"""
    print("\n🔒 测试证书上传token")
    print("===================")
    
    url = "https://api.qiniu.com/sslcert"
    
    # 简化的测试数据
    test_data = {
        "name": "test-cert",
        "common_name": "test.example.com", 
        "pri": "test-private-key",
        "ca": "test-certificate"
    }
    body = json.dumps(test_data)
    
    token = generate_management_token("POST", url, body)
    
    # 实际测试请求
    headers = {
        "Content-Type": "application/json",
        "Authorization": token
    }
    
    try:
        response = requests.post(url, data=body, headers=headers, timeout=10)
        print(f"响应状态: {response.status_code}")
        print(f"响应内容: {response.text}")
        
        if response.status_code == 401:
            print("❌ 仍然是认证失败")
        elif response.status_code == 200:
            print("✅ 认证成功!")
        else:
            print(f"⚠️ 其他状态码: {response.status_code}")
            
    except Exception as e:
        print(f"❌ 请求异常: {e}")

def main():
    if not QINIU_ACCESS_KEY or not QINIU_SECRET_KEY:
        print("❌ 未找到七牛云环境变量")
        return
    
    print(f"🔧 七牛云管理凭证验证")
    print(f"ACCESS_KEY: {QINIU_ACCESS_KEY[:10]}...{QINIU_ACCESS_KEY[-4:]}")
    print(f"SECRET_KEY: {QINIU_SECRET_KEY[:10]}...{QINIU_SECRET_KEY[-4:]}\n")
    
    # 先测试官方示例
    test_official_example()
    
    # 再测试我们的场景
    test_cert_upload()

if __name__ == "__main__":
    main() 
