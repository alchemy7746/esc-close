#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
APP_NAME="EscClose"
VERSION="$(plutil -extract CFBundleShortVersionString raw "$ROOT_DIR/Resources/Info.plist")"
BUILD_DIR="$ROOT_DIR/.build/release"
APP_PATH="$ROOT_DIR/dist/$APP_NAME.app"
ZIP_PATH="$ROOT_DIR/dist/$APP_NAME-$VERSION.zip"
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"

rm -rf "$BUILD_DIR" "$APP_PATH"
mkdir -p "$BUILD_DIR" "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources" "$ROOT_DIR/dist"

xcrun swiftc -O -whole-module-optimization -parse-as-library \
    -target x86_64-apple-macosx12.0 \
    -sdk "$SDK_PATH" \
    -framework AppKit -framework ApplicationServices -framework CoreGraphics \
    "$ROOT_DIR/Sources/EscClose/EscClose.swift" \
    -o "$BUILD_DIR/EscClose-x86_64"

xcrun swiftc -O -whole-module-optimization -parse-as-library \
    -target arm64-apple-macosx12.0 \
    -sdk "$SDK_PATH" \
    -framework AppKit -framework ApplicationServices -framework CoreGraphics \
    "$ROOT_DIR/Sources/EscClose/EscClose.swift" \
    -o "$BUILD_DIR/EscClose-arm64"

lipo -create \
    "$BUILD_DIR/EscClose-x86_64" \
    "$BUILD_DIR/EscClose-arm64" \
    -output "$APP_PATH/Contents/MacOS/EscClose"

xcrun swift "$ROOT_DIR/scripts/make_icon.swift" "$BUILD_DIR/icon_1024.png"
ICONSET="$BUILD_DIR/AppIcon.iconset"
mkdir -p "$ICONSET"

sips -z 16 16 "$BUILD_DIR/icon_1024.png" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32 "$BUILD_DIR/icon_1024.png" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$BUILD_DIR/icon_1024.png" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64 "$BUILD_DIR/icon_1024.png" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$BUILD_DIR/icon_1024.png" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256 "$BUILD_DIR/icon_1024.png" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$BUILD_DIR/icon_1024.png" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512 "$BUILD_DIR/icon_1024.png" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$BUILD_DIR/icon_1024.png" --out "$ICONSET/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$BUILD_DIR/icon_1024.png" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET" -o "$APP_PATH/Contents/Resources/AppIcon.icns"

cp "$ROOT_DIR/Resources/Info.plist" "$APP_PATH/Contents/Info.plist"
chmod +x "$APP_PATH/Contents/MacOS/EscClose"

if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
    codesign --force --deep --options runtime --timestamp \
        --sign "$CODESIGN_IDENTITY" "$APP_PATH"
else
    codesign --force --deep --sign - "$APP_PATH"
fi

COPYFILE_DISABLE=1 ditto -c -k --norsrc --noextattr --keepParent "$APP_PATH" "$ZIP_PATH"

echo "Built: $APP_PATH"
echo "Package: $ZIP_PATH"
