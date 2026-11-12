.PHONY: assets generate build test run clean

CONFIG ?= Release
DERIVED := .derived

# 从仓库内品牌 SVG 生成 AppIcon.icns 与菜单栏模板图标
assets:
	swift scripts/generate-assets.swift assets/logo.svg maclean/Resources/Assets.xcassets maclean/Resources/AppIcon.icns

# 由 project.yml 生成 Xcode 工程
generate:
	xcodegen generate

build: generate
	xcodebuild -project maclean.xcodeproj -scheme maclean -configuration $(CONFIG) \
		-derivedDataPath $(DERIVED) -destination 'platform=macOS' \
		build CONFIGURATION_BUILD_DIR=$(CURDIR)/build

test: generate
	xcodebuild -project maclean.xcodeproj -scheme maclean -configuration Debug \
		-derivedDataPath $(DERIVED) -destination 'platform=macOS' test

run: build
	open build/maclean.app

# 构建安装包（DMG + PKG），输出到 dist/
package: build
	scripts/package.sh

clean:
	rm -rf $(DERIVED) build dist maclean.xcodeproj
