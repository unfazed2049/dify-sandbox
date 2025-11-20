import ctypes
import json
import os
import sys
import traceback
from base64 import b64decode
from json import dumps, loads

# setup sys.excepthook
def excepthook(type, value, tb):
    sys.stderr.write("".join(traceback.format_exception(type, value, tb)))
    sys.stderr.flush()
    sys.exit(-1)


sys.excepthook = excepthook

lib = ctypes.CDLL("/var/sandbox/sandbox-python/python.so")
lib.DifySeccomp.argtypes = [ctypes.c_uint32, ctypes.c_uint32, ctypes.c_bool]
lib.DifySeccomp.restype = None

os.chdir("/var/sandbox/sandbox-python")

lib.DifySeccomp(65537, 1001, 1)

from Crypto.Cipher import AES
from Crypto.Util.Padding import unpad
from Crypto.Protocol.KDF import PBKDF2
import hashlib

def decrypt_cookie(ciphertext, uuid, password):
     # 生成解密密钥 (MD5(uuid + '-' + password)的前16位)
    hash_str = hashlib.md5(f"{uuid}-{password}".encode()).hexdigest()
    key = hash_str[:16].encode()

    # 原有的 legacy 算法
    # 分离salt和IV (CryptoJS格式)
    encrypted = b64decode(ciphertext)
    salt = encrypted[8:16]
    ct = encrypted[16:]

    # 使用OpenSSL EVP_BytesToKey导出方式
    key_iv = b""
    prev = b""
    while len(key_iv) < 48:
        prev = hashlib.md5(prev + key + salt).digest()
        key_iv += prev

    _key = key_iv[:32]
    _iv = key_iv[32:48]

    # 创建cipher并解密
    cipher = AES.new(_key, AES.MODE_CBC, _iv)
    pt = unpad(cipher.decrypt(ct), AES.block_size)
    return json.loads(pt.decode('utf-8'))


def main():
    return {}
