#!/bin/zsh
# 构建自用安装包：DMG（拖拽安装）+ PKG（安装器安装）。
# 用法：scripts/package.sh [版本号]（默认读 build/maclean.app 的 Info.plist）
# 前置：先 make build（build/maclean.app 存在且为 maclean-dev 签名）。
# 自用分发不做公证：本机生成的 DMG 无隔离属性，直接可用；
# 若拷贝到其他机器，首次打开需右键 → 打开（Gatekeeper 对未公证包的正常行为）。

set -e
cd "$(dirname "$0")/.."

APP="build/maclean.app"
[[ -d "$APP" ]] || { echo "❌ 未找到 $APP，请先 make build"; exit 1; }

# 版本号
VERSION="${1:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")}"
OUT_DIR="dist"
STAGING="$OUT_DIR/staging"
DMG="$OUT_DIR/maclean-$VERSION.dmg"
PKG="$OUT_DIR/maclean-$VERSION.pkg"

# 签名校验（防止把坏包封进去）
codesign --verify --strict "$APP" || { echo "❌ 签名校验失败"; exit 1; }

rm -rf "$OUT_DIR"
mkdir -p "$STAGING"

# --- DMG：App + Applications 快捷方式 ---
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "maclean $VERSION" \
  -srcfolder "$STAGING" \
  -ov -format UDZO \
  "$DMG" > /dev/null
echo "✅ DMG：$DMG"

# --- PKG：安装到 /Applications ---
pkgbuild --install-location /Applications \
  --component "$APP" \
  "$PKG" > /dev/null
echo "✅ PKG：$PKG"

rm -rf "$STAGING"

echo
ls -lh "$DMG" "$PKG" | awk '{print $5, $9}'
