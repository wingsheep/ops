#!/usr/bin/env python3
"""
自动化Let's Encrypt证书上传到七牛云CDN脚本
用途：解决Let's Encrypt证书3个月过期的问题，自动续期并上传到七牛云
"""
import os
import sys
import json
import logging
import requests
from datetime import datetime
from qiniu import Auth
import hmac
import hashlib
import base64
from urllib.parse import urlencode

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s: %(message)s',
    handlers=[
        logging.FileHandler('/etc/nginx/qiniu_cert_upload.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

# 七牛云配置
QINIU_ACCESS_KEY = os.getenv("QINIU_ACCESS_KEY")
QINIU_SECRET_KEY = os.getenv("QINIU_SECRET_KEY") 
QINIU_CERT_NAME = "file-example-com-auto"  # 证书在七牛云显示的名称
QINIU_CDN_DOMAIN = "file.example.com"      # 需要更新证书的CDN域名

# Let's Encrypt 证书路径
CERT_PATH = "/etc/letsencrypt/live/file.example.com/fullchain.pem"
PRIVATE_KEY_PATH = "/etc/letsencrypt/live/file.example.com/privkey.pem"

class QiniuCertManager:
    def __init__(self, access_key, secret_key):
        self.access_key = access_key
        self.secret_key = secret_key
        self.auth = Auth(access_key, secret_key)
        self.base_url = "https://api.qiniu.com"
        
    def _generate_qbox_token(self, method, url, body=None):
        """生成QBox认证token - 根据实际工作的实现方式"""
        from urllib.parse import urlparse
        parsed_url = urlparse(url)
        path = parsed_url.path
        if parsed_url.query:
            path += '?' + parsed_url.query
        
        # 构建待签名字符串 - 关键：只使用path，不包含body！
        # 根据博客实践经验，SSL证书API的签名只包含path部分
        auth_str = path + '\n'
        
        # 调试输出
        logger.info(f"待签名字符串: {repr(auth_str)}")
        
        # 生成签名
        signature = hmac.new(
            self.secret_key.encode('utf-8'),
            auth_str.encode('utf-8'),
            hashlib.sha1
        ).digest()
        encoded_sign = base64.urlsafe_b64encode(signature).decode('utf-8')
        
        token = f"QBox {self.access_key}:{encoded_sign}"
        logger.info(f"生成的token: {token}")
        
        return token

    def upload_certificate(self, cert_name, cert_content, private_key):
        """上传证书到七牛云"""
        url = f"{self.base_url}/sslcert"
        
        data = {
            "name": cert_name,
            "common_name": QINIU_CDN_DOMAIN,
            "pri": private_key,
            "ca": cert_content
        }
        
        # 使用QBox认证方式 (根据官方文档: Authorization: QBox <AccessToken>)
        body = json.dumps(data)
        access_token = self._generate_qbox_token("POST", url, body)
        
        # 调试信息
        logger.info(f"生成的AccessToken: {access_token[:50]}...")
        logger.info(f"请求URL: {url}")
        logger.info(f"请求体: {body}")
        
        headers = {
            "Content-Type": "application/json",
            "Authorization": access_token
        }
        
        logger.info(f"完整Authorization header: {access_token[:50]}...")
        
        try:
            response = requests.post(url, data=body, headers=headers, timeout=30)
            logger.info(f"证书上传响应状态: {response.status_code}")
            logger.info(f"证书上传响应: {response.text}")
            
            if response.status_code == 200:
                result = response.json()
                cert_id = result.get("certID")
                logger.info(f"证书上传成功，CertID: {cert_id}")
                return cert_id
            else:
                logger.error(f"证书上传失败: {response.text}")
                return None
                
        except Exception as e:
            logger.error(f"证书上传异常: {str(e)}")
            return None

    def get_certificate_list(self):
        """获取证书列表"""
        url = f"{self.base_url}/sslcert"
        # 使用QBox认证方式
        token = self._generate_qbox_token("GET", url)
        
        headers = {
            "Authorization": token
        }
        
        try:
            response = requests.get(url, headers=headers, timeout=30)
            if response.status_code == 200:
                return response.json()
            else:
                logger.error(f"获取证书列表失败: {response.text}")
                return None
        except Exception as e:
            logger.error(f"获取证书列表异常: {str(e)}")
            return None

    def delete_certificate(self, cert_id):
        """删除证书"""
        url = f"{self.base_url}/sslcert/{cert_id}"
        # 使用QBox认证方式
        token = self._generate_qbox_token("DELETE", url)
        
        headers = {
            "Authorization": token
        }
        
        try:
            response = requests.delete(url, headers=headers, timeout=30)
            if response.status_code == 200:
                logger.info(f"证书删除成功: {cert_id}")
                return True
            else:
                logger.error(f"证书删除失败: {response.text}")
                return False
        except Exception as e:
            logger.error(f"证书删除异常: {str(e)}")
            return False

    def update_domain_certificate(self, domain, cert_id):
        """更新域名的证书配置"""
        # 注意：这里需要调用七牛云的域名配置API
        # 具体API可能需要根据七牛云最新文档调整
        url = f"{self.base_url}/domain/{domain}/httpsconf"
        
        data = {
            "certid": cert_id,
            "forceHttps": False  # 根据需求调整
        }
        
        # 使用QBox认证方式
        body = json.dumps(data)
        token = self._generate_qbox_token("PUT", url, body)
        
        headers = {
            "Content-Type": "application/json", 
            "Authorization": token
        }
        
        try:
            response = requests.put(url, data=body, headers=headers, timeout=30)
            logger.info(f"域名证书更新响应: {response.status_code}, {response.text}")
            
            if response.status_code == 200:
                logger.info(f"域名 {domain} 证书更新成功")
                return True
            else:
                logger.error(f"域名 {domain} 证书更新失败: {response.text}")
                return False
                
        except Exception as e:
            logger.error(f"域名证书更新异常: {str(e)}")
            return False

def cleanup_old_certificates(cert_manager, cert_name_prefix):
    """清理旧证书"""
    cert_list = cert_manager.get_certificate_list()
    if not cert_list:
        return
        
    certs = cert_list.get("certs", [])
    old_certs = [cert for cert in certs if cert.get("name", "").startswith(cert_name_prefix)]
    
    # 保留最新的2个证书，删除其他旧证书
    if len(old_certs) > 2:
        old_certs.sort(key=lambda x: x.get("create_time", 0))
        for cert in old_certs[:-2]:
            cert_id = cert.get("certid")
            logger.info(f"删除旧证书: {cert.get('name')} ({cert_id})")
            cert_manager.delete_certificate(cert_id)

def main():
    # 检查环境变量
    if not QINIU_ACCESS_KEY or not QINIU_SECRET_KEY:
        logger.error("请设置环境变量 QINIU_ACCESS_KEY 和 QINIU_SECRET_KEY")
        sys.exit(1)
    
    # 检查证书文件是否存在
    if not os.path.exists(CERT_PATH) or not os.path.exists(PRIVATE_KEY_PATH):
        logger.error(f"证书文件不存在: {CERT_PATH} 或 {PRIVATE_KEY_PATH}")
        sys.exit(1)
    
    try:
        # 读取证书文件
        with open(CERT_PATH, 'r') as f:
            cert_content = f.read()
        with open(PRIVATE_KEY_PATH, 'r') as f:
            private_key_content = f.read()
            
        logger.info("证书文件读取成功")
        
        # 初始化证书管理器
        cert_manager = QiniuCertManager(QINIU_ACCESS_KEY, QINIU_SECRET_KEY)
        
        # 生成带时间戳的证书名称
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        cert_name = f"{QINIU_CERT_NAME}_{timestamp}"
        
        # 上传新证书
        cert_id = cert_manager.upload_certificate(cert_name, cert_content, private_key_content)
        if not cert_id:
            logger.error("证书上传失败")
            sys.exit(1)
        
        # 更新域名证书配置
        if cert_manager.update_domain_certificate(QINIU_CDN_DOMAIN, cert_id):
            logger.info("证书更新成功")
            
            # 清理旧证书
            cleanup_old_certificates(cert_manager, QINIU_CERT_NAME)
            
            logger.info("自动化证书更新流程完成")
        else:
            logger.error("域名证书配置更新失败")
            sys.exit(1)
            
    except Exception as e:
        logger.error(f"执行失败: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    main()
