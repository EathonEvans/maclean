#!/bin/zsh
# 重建 maclean-dev 自签名代码签名证书并导入登录钥匙串。
# 用途：换机器或钥匙串丢失证书时恢复。密码固定为 maclean-dev（仅本地开发用）。
# 依赖：openssl（Homebrew 或系统自带）、security（系统自带）。

set -e

CERT_DIR="$(mktemp -d)"
trap 'rm -rf "$CERT_DIR"' EXIT

openssl req -newkey rsa:2048 -nodes -keyout "$CERT_DIR/key.pem" \
  -x509 -days 3650 -out "$CERT_DIR/cert.pem" \
  -subj "/CN=maclean-dev/OU=maclean/O=maclean" \
  -addext "keyUsage=digitalSignature" \
  -addext "extendedKeyUsage=codeSigning"

# macOS 钥匙串只认旧版 PKCS12 加密算法，必须用 -keypbe/-certpbe/-macalg
openssl pkcs12 -export -out "$CERT_DIR/cert-legacy.p12" \
  -inkey "$CERT_DIR/key.pem" -in "$CERT_DIR/cert.pem" \
  -passout pass:maclean-dev \
  -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1

security import "$CERT_DIR/cert-legacy.p12" \
  -k ~/Library/Keychains/login.keychain-db \
  -P maclean-dev -T /usr/bin/codesign

security add-trusted-cert -r trustRoot \
  -k ~/Library/Keychains/login.keychain-db "$CERT_DIR/cert.pem"

echo "✅ maclean-dev 证书已导入，验证："
security find-identity -v -p codesigning | grep maclean-dev || true
