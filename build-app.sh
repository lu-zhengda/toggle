#!/bin/bash
# Build Toggle and package it into a menu-bar-only .app bundle.
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Toggle"
BUNDLE_ID="com.local.toggle"
APP_DIR="build/${APP_NAME}.app"

echo "==> Building release binary..."
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/${APP_NAME}"

echo "==> Assembling ${APP_DIR}..."
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"
cp "${BIN_PATH}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"

echo "==> Generating app icon..."
if swift generate-icon.swift build/icon.png >/dev/null 2>&1; then
    ICONSET="build/AppIcon.iconset"
    rm -rf "${ICONSET}"; mkdir -p "${ICONSET}"
    for s in 16 32 64 128 256 512 1024; do
        sips -z $s $s build/icon.png --out "${ICONSET}/icon_${s}x${s}.png" >/dev/null 2>&1
    done
    # Retina @2x variants the iconset format expects.
    cp "${ICONSET}/icon_32x32.png"   "${ICONSET}/icon_16x16@2x.png"
    cp "${ICONSET}/icon_64x64.png"   "${ICONSET}/icon_32x32@2x.png"
    cp "${ICONSET}/icon_256x256.png" "${ICONSET}/icon_128x128@2x.png"
    cp "${ICONSET}/icon_512x512.png" "${ICONSET}/icon_256x256@2x.png"
    cp "${ICONSET}/icon_1024x1024.png" "${ICONSET}/icon_512x512@2x.png"
    rm -f "${ICONSET}/icon_64x64.png" "${ICONSET}/icon_1024x1024.png"
    iconutil -c icns "${ICONSET}" -o "${APP_DIR}/Contents/Resources/AppIcon.icns" 2>/dev/null \
        && echo "    icon embedded" || echo "    icon skipped"
fi

cat > "${APP_DIR}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key><string>${APP_NAME}</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleVersion</key><string>1.1.0</string>
    <key>CFBundleShortVersionString</key><string>1.1.0</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>Toggle uses automation to control system appearance, audio, and Finder.</string>
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>Toggle uses Bluetooth to toggle the controller and connect AirPods.</string>
</dict>
</plist>
PLIST

echo "==> Ad-hoc code signing..."
codesign --force --deep --sign - "${APP_DIR}" 2>/dev/null || true

echo "==> Done: ${APP_DIR}"
