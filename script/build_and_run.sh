#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="PaperMon"
BUNDLE_ID="com.papermon.app"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_FRAMEWORKS="$APP_CONTENTS/Frameworks"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ASSET_CATALOG="$ROOT_DIR/PaperMon/Resources/Assets.xcassets"
ASSET_INFO_PLIST="$DIST_DIR/assetcatalog-info.plist"
SPARKLE_FRAMEWORK_SOURCE="$ROOT_DIR/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
SPARKLE_FRAMEWORK="$APP_FRAMEWORKS/Sparkle.framework"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

swift build --package-path "$ROOT_DIR" --product "$APP_NAME"
BUILD_BINARY="$(swift build --package-path "$ROOT_DIR" --show-bin-path)/$APP_NAME"

mkdir -p "$APP_MACOS" "$APP_RESOURCES" "$APP_FRAMEWORKS"
cp -f "$BUILD_BINARY" "$APP_BINARY"
cp -f "$ROOT_DIR/Packaging/Info.plist" "$INFO_PLIST"
rm -rf "$SPARKLE_FRAMEWORK"
ditto "$SPARKLE_FRAMEWORK_SOURCE" "$SPARKLE_FRAMEWORK"
xcrun actool "$ASSET_CATALOG" \
  --compile "$APP_RESOURCES" \
  --platform macosx \
  --minimum-deployment-target 14.0 \
  --target-device mac \
  --app-icon AppIcon \
  --output-partial-info-plist "$ASSET_INFO_PLIST" \
  --output-format human-readable-text \
  --notices \
  --warnings
chmod +x "$APP_BINARY"
/usr/bin/codesign --force --sign - --options runtime --preserve-metadata=entitlements "$SPARKLE_FRAMEWORK/Versions/B/XPCServices/Installer.xpc"
/usr/bin/codesign --force --sign - --options runtime --preserve-metadata=entitlements "$SPARKLE_FRAMEWORK/Versions/B/XPCServices/Downloader.xpc"
/usr/bin/codesign --force --sign - --options runtime --preserve-metadata=entitlements "$SPARKLE_FRAMEWORK/Versions/B/Autoupdate"
/usr/bin/codesign --force --sign - --options runtime --preserve-metadata=entitlements "$SPARKLE_FRAMEWORK/Versions/B/Updater.app"
/usr/bin/codesign --force --sign - --options runtime "$SPARKLE_FRAMEWORK"
/usr/bin/codesign \
  --force \
  --sign - \
  --entitlements "$ROOT_DIR/PaperMon/PaperMon.entitlements" \
  "$APP_BUNDLE"

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
