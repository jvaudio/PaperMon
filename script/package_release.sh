#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="PaperMon"
ENTITLEMENTS="$ROOT_DIR/PaperMon/PaperMon.entitlements"
INFO_PLIST_SOURCE="$ROOT_DIR/Packaging/Info.plist"
OUTPUT_DIR="$ROOT_DIR/dist/release"
ASSET_CATALOG="$ROOT_DIR/PaperMon/Resources/Assets.xcassets"

IDENTITY=""
NOTARY_PROFILE=""
VERSION="0.1.0"
BUILD_NUMBER="1"
AD_HOC=0

usage() {
  echo "usage: $0 (--identity <developer-id> | --ad-hoc) [--notary-profile <profile>] [--version <version>] [--build <number>]" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --identity)
      IDENTITY="${2:-}"
      shift 2
      ;;
    --notary-profile)
      NOTARY_PROFILE="${2:-}"
      shift 2
      ;;
    --version)
      VERSION="${2:-}"
      shift 2
      ;;
    --build)
      BUILD_NUMBER="${2:-}"
      shift 2
      ;;
    --ad-hoc)
      AD_HOC=1
      IDENTITY="-"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

if [[ -z "$IDENTITY" ]]; then
  usage
  exit 2
fi

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9]+)*$ ]]; then
  echo "Version must use a semantic version such as 1.0.0 or 1.0.0-beta1." >&2
  exit 2
fi

if [[ ! "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "Build number must contain digits only." >&2
  exit 2
fi

if [[ $AD_HOC -eq 1 && -n "$NOTARY_PROFILE" ]]; then
  echo "Ad-hoc builds cannot be notarized." >&2
  exit 2
fi

for command_name in swift lipo codesign diskutil ditto plutil; do
  if ! command -v "$command_name" >/dev/null; then
    echo "Missing required command: $command_name" >&2
    exit 1
  fi
done

if [[ $AD_HOC -eq 0 ]]; then
  AVAILABLE_IDENTITIES="$(security find-identity -v -p codesigning)"
  if [[ "$AVAILABLE_IDENTITIES" != *"$IDENTITY"* ]]; then
    echo "The requested signing identity is not available in the keychain: $IDENTITY" >&2
    exit 1
  fi
fi

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/papermon-release.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

ARM64_SCRATCH="$WORK_DIR/arm64"
X86_64_SCRATCH="$WORK_DIR/x86_64"
STAGED_APP="$WORK_DIR/$APP_NAME.app"
STAGED_BINARY="$STAGED_APP/Contents/MacOS/$APP_NAME"
STAGED_FRAMEWORKS="$STAGED_APP/Contents/Frameworks"
STAGED_RESOURCES="$STAGED_APP/Contents/Resources"
DMG_ROOT="$WORK_DIR/dmg"
OUTPUT_APP="$OUTPUT_DIR/$APP_NAME-$VERSION.app"
OUTPUT_DMG="$OUTPUT_DIR/$APP_NAME-$VERSION.dmg"

mkdir -p "$OUTPUT_DIR"

swift build \
  --package-path "$ROOT_DIR" \
  --configuration release \
  --scratch-path "$ARM64_SCRATCH" \
  --triple arm64-apple-macosx14.0 \
  --product "$APP_NAME"

swift build \
  --package-path "$ROOT_DIR" \
  --configuration release \
  --scratch-path "$X86_64_SCRATCH" \
  --triple x86_64-apple-macosx14.0 \
  --product "$APP_NAME"

ARM64_BIN_DIR="$(swift build --package-path "$ROOT_DIR" --configuration release --scratch-path "$ARM64_SCRATCH" --triple arm64-apple-macosx14.0 --show-bin-path)"
X86_64_BIN_DIR="$(swift build --package-path "$ROOT_DIR" --configuration release --scratch-path "$X86_64_SCRATCH" --triple x86_64-apple-macosx14.0 --show-bin-path)"
SPARKLE_ARTIFACT_DIR="$ARM64_SCRATCH/artifacts/sparkle/Sparkle"
SPARKLE_FRAMEWORK_SOURCE="$SPARKLE_ARTIFACT_DIR/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
GENERATE_APPCAST="$SPARKLE_ARTIFACT_DIR/bin/generate_appcast"

mkdir -p "$STAGED_APP/Contents/MacOS" "$STAGED_FRAMEWORKS" "$STAGED_RESOURCES"
cp "$INFO_PLIST_SOURCE" "$STAGED_APP/Contents/Info.plist"
ditto "$SPARKLE_FRAMEWORK_SOURCE" "$STAGED_FRAMEWORKS/Sparkle.framework"
xcrun actool "$ASSET_CATALOG" \
  --compile "$STAGED_RESOURCES" \
  --platform macosx \
  --minimum-deployment-target 14.0 \
  --target-device mac \
  --app-icon AppIcon \
  --output-partial-info-plist "$WORK_DIR/assetcatalog-info.plist" \
  --output-format human-readable-text \
  --notices \
  --warnings
lipo -create \
  "$ARM64_BIN_DIR/$APP_NAME" \
  "$X86_64_BIN_DIR/$APP_NAME" \
  -output "$STAGED_BINARY"
chmod +x "$STAGED_BINARY"
plutil -replace CFBundleShortVersionString -string "$VERSION" "$STAGED_APP/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$STAGED_APP/Contents/Info.plist"

SPARKLE_FRAMEWORK="$STAGED_FRAMEWORKS/Sparkle.framework"
SPARKLE_CODESIGN_ARGS=(--force --sign "$IDENTITY" --options runtime)
if [[ $AD_HOC -eq 0 ]]; then
  SPARKLE_CODESIGN_ARGS+=(--timestamp)
fi

codesign "${SPARKLE_CODESIGN_ARGS[@]}" --preserve-metadata=entitlements "$SPARKLE_FRAMEWORK/Versions/B/XPCServices/Installer.xpc"
codesign "${SPARKLE_CODESIGN_ARGS[@]}" --preserve-metadata=entitlements "$SPARKLE_FRAMEWORK/Versions/B/XPCServices/Downloader.xpc"
codesign "${SPARKLE_CODESIGN_ARGS[@]}" --preserve-metadata=entitlements "$SPARKLE_FRAMEWORK/Versions/B/Autoupdate"
codesign "${SPARKLE_CODESIGN_ARGS[@]}" --preserve-metadata=entitlements "$SPARKLE_FRAMEWORK/Versions/B/Updater.app"
codesign "${SPARKLE_CODESIGN_ARGS[@]}" "$SPARKLE_FRAMEWORK"

if [[ $AD_HOC -eq 1 ]]; then
  codesign \
    --force \
    --sign - \
    --entitlements "$ENTITLEMENTS" \
    "$STAGED_APP"
else
  codesign \
    --force \
    --options runtime \
    --timestamp \
    --sign "$IDENTITY" \
    --entitlements "$ENTITLEMENTS" \
    "$STAGED_APP"
fi

codesign --verify --deep --strict --verbose=2 "$STAGED_APP"

if [[ -n "$NOTARY_PROFILE" ]]; then
  NOTARY_ZIP="$WORK_DIR/$APP_NAME-$VERSION.zip"
  ditto -c -k --keepParent "$STAGED_APP" "$NOTARY_ZIP"
  xcrun notarytool submit "$NOTARY_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$STAGED_APP"
  xcrun stapler validate "$STAGED_APP"
  spctl --assess --type execute --verbose=4 "$STAGED_APP"
fi

mkdir -p "$DMG_ROOT"
ditto "$STAGED_APP" "$DMG_ROOT/$APP_NAME.app"
ln -s /Applications "$DMG_ROOT/Applications"

if [[ -e "$OUTPUT_DMG" ]]; then
  rm "$OUTPUT_DMG"
fi
diskutil image create from \
  --volumeName "$APP_NAME $VERSION" \
  --format UDZO \
  "$DMG_ROOT" \
  "$OUTPUT_DMG"

if [[ $AD_HOC -eq 0 ]]; then
  codesign --force --timestamp --sign "$IDENTITY" "$OUTPUT_DMG"
fi

if [[ -n "$NOTARY_PROFILE" ]]; then
  xcrun notarytool submit "$OUTPUT_DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$OUTPUT_DMG"
  xcrun stapler validate "$OUTPUT_DMG"
  spctl --assess --type open --context context:primary-signature --verbose=4 "$OUTPUT_DMG"
fi

rm -rf "$OUTPUT_APP"
ditto "$STAGED_APP" "$OUTPUT_APP"

if [[ $AD_HOC -eq 0 ]]; then
  APPCAST_DIR="$WORK_DIR/appcast"
  mkdir -p "$APPCAST_DIR"
  ditto "$OUTPUT_DMG" "$APPCAST_DIR/$(basename "$OUTPUT_DMG")"
  "$GENERATE_APPCAST" \
    --download-url-prefix "https://github.com/jvaudio/PaperMon/releases/download/v$VERSION/" \
    "$APPCAST_DIR"
  ditto "$APPCAST_DIR/appcast.xml" "$ROOT_DIR/appcast.xml"
fi

echo
echo "Release artifacts:"
echo "  $OUTPUT_APP"
echo "  $OUTPUT_DMG"
shasum -a 256 "$OUTPUT_DMG"

if [[ $AD_HOC -eq 1 ]]; then
  echo "Ad-hoc validation build complete. It is not suitable for distribution."
elif [[ -z "$NOTARY_PROFILE" ]]; then
  echo "Developer ID signed build complete. Notarization was skipped because no keychain profile was provided."
else
  echo "Developer ID signed and notarized release complete."
fi

if [[ $AD_HOC -eq 0 ]]; then
  echo "  $ROOT_DIR/appcast.xml"
  echo "Publish the DMG in GitHub release v$VERSION, then commit and push appcast.xml."
fi
