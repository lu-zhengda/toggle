#!/bin/bash
# Build Toggle and package it into a menu-bar-only .app bundle.
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Toggle"
BUNDLE_ID="com.local.toggle"
APP_DIR="build/${APP_NAME}.app"
APP_BINARY="${APP_DIR}/Contents/MacOS/${APP_NAME}"
APP_ICON="${APP_DIR}/Contents/Resources/AppIcon.icns"
INFO_PLIST="${APP_DIR}/Contents/Info.plist"
BUILD_ARGS=(-c release --arch arm64 --arch x86_64)

fail() {
    echo "error: $*" >&2
    exit 1
}

echo "==> Building universal release binary (arm64 + x86_64)..."
swift build "${BUILD_ARGS[@]}"

BIN_PATH="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)/${APP_NAME}"
[ -x "${BIN_PATH}" ] || fail "release binary missing or not executable: ${BIN_PATH}"

echo "==> Assembling ${APP_DIR}..."
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"
cp "${BIN_PATH}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"

echo "==> Generating app icon..."
rm -f build/icon.png
swift generate-icon.swift build/icon.png
[ -s build/icon.png ] || fail "icon generator did not produce build/icon.png"

ICONSET="build/AppIcon.iconset"
rm -rf "${ICONSET}"
mkdir -p "${ICONSET}"
for s in 16 32 64 128 256 512 1024; do
    sips -z "${s}" "${s}" build/icon.png --out "${ICONSET}/icon_${s}x${s}.png" >/dev/null
done
# Retina @2x variants the iconset format expects.
cp "${ICONSET}/icon_32x32.png"   "${ICONSET}/icon_16x16@2x.png"
cp "${ICONSET}/icon_64x64.png"   "${ICONSET}/icon_32x32@2x.png"
cp "${ICONSET}/icon_256x256.png" "${ICONSET}/icon_128x128@2x.png"
cp "${ICONSET}/icon_512x512.png" "${ICONSET}/icon_256x256@2x.png"
cp "${ICONSET}/icon_1024x1024.png" "${ICONSET}/icon_512x512@2x.png"
rm -f "${ICONSET}/icon_64x64.png" "${ICONSET}/icon_1024x1024.png"
iconutil -c icns "${ICONSET}" -o "${APP_ICON}"
[ -s "${APP_ICON}" ] || fail "iconutil did not produce ${APP_ICON}"
echo "    icon embedded"

cat > "${INFO_PLIST}" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key><string>${APP_NAME}</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleVersion</key><string>1.3.0</string>
    <key>CFBundleShortVersionString</key><string>1.3.0</string>
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
codesign --force --sign - "${APP_DIR}"

echo "==> Verifying app bundle..."
plutil -lint "${INFO_PLIST}"
[ -s "${APP_ICON}" ] || fail "app icon is missing: ${APP_ICON}"
[ -x "${APP_BINARY}" ] || fail "app executable is missing: ${APP_BINARY}"

BUNDLE_EXECUTABLE="$(plutil -extract CFBundleExecutable raw "${INFO_PLIST}")"
[ "${BUNDLE_EXECUTABLE}" = "${APP_NAME}" ] \
    || fail "CFBundleExecutable is ${BUNDLE_EXECUTABLE}, expected ${APP_NAME}"
BUNDLE_VERSION="$(plutil -extract CFBundleVersion raw "${INFO_PLIST}")"
SHORT_VERSION="$(plutil -extract CFBundleShortVersionString raw "${INFO_PLIST}")"
[ "${BUNDLE_VERSION}" = "${SHORT_VERSION}" ] \
    || fail "bundle versions differ: ${BUNDLE_VERSION} vs ${SHORT_VERSION}"

ACTUAL_ARCHS="$(lipo -archs "${APP_BINARY}")"
for arch in arm64 x86_64; do
    case " ${ACTUAL_ARCHS} " in
        *" ${arch} "*) ;;
        *) fail "missing ${arch} architecture (found: ${ACTUAL_ARCHS})" ;;
    esac
done
codesign --verify --deep --strict --verbose=2 "${APP_DIR}"
echo "    plist valid; icon present; architectures: ${ACTUAL_ARCHS}; signature valid"

echo "==> Done: ${APP_DIR}"
