#!/bin/bash
set -e

APP_NAME="LivePowerFlow"
BUILD_DIR="$(pwd)/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
MACOS_DIR="$APP_BUNDLE/Contents/MacOS"
RESOURCES_DIR="$APP_BUNDLE/Contents/Resources"

echo "🔨 准备构建 $APP_NAME.app..."
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# 写入 Info.plist (设置 LSUIElement 为 true，纯菜单栏应用，不占活动 Dock；可固定于 Dock 便于点击启动)
cat << 'EOF' > "$APP_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>LivePowerFlow</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.LivePowerFlow</string>
    <key>CFBundleName</key>
    <string>LivePowerFlow</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

echo "⚡️ 正在编译 Swift 源代码..."
swiftc -parse-as-library \
    -module-cache-path /tmp/clang-cache \
    -O \
    Sources/PowerModel.swift \
    Sources/LiquidGlassStyle.swift \
    Sources/SankeyView.swift \
    Sources/PowerFlowPopoverView.swift \
    Sources/LivePowerFlowApp.swift \
    -o "$MACOS_DIR/$APP_NAME"

echo "✅ 构建成功: $APP_BUNDLE"
