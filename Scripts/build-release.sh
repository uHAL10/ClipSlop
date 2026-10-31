#!/bin/bash
set -euo pipefail

if [ "$#" -ne 1 ] || [[ ! "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Usage: $0 <major.minor.patch>" >&2
    exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

VERSION="$1"
OUTPUT="$PROJECT_DIR/.build/distribution/$VERSION"
if [ -e "$OUTPUT" ]; then
    echo "Output already exists: $OUTPUT" >&2
    exit 1
fi

# Removed resources must not survive in an incremental release bundle.
swift package --scratch-path "$PROJECT_DIR/.build/apple" clean
swift build -c release --arch arm64 --arch x86_64

BUILD_DIR="$PROJECT_DIR/.build/apple/Products/Release"
SPARKLE="$PROJECT_DIR/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
APP="$OUTPUT/ClipSlop.app"
CONTENTS="$APP/Contents"
STAGING="$OUTPUT/dmg-contents"
DMG="$OUTPUT/ClipSlop-$VERSION-macOS.dmg"

test -f "$BUILD_DIR/ClipSlop"
test -d "$BUILD_DIR/ClipSlop_ClipSlop.bundle"
test -d "$SPARKLE"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources" "$CONTENTS/Frameworks"
cp "$BUILD_DIR/ClipSlop" "$CONTENTS/MacOS/ClipSlop"
cp SupportingFiles/Info.plist "$CONTENTS/Info.plist"
cp SupportingFiles/AppIcon.icns "$CONTENTS/Resources/AppIcon.icns"
cp -R "$BUILD_DIR"/*.bundle "$CONTENTS/Resources/"
cp -R "$SPARKLE" "$CONTENTS/Frameworks/"
for locale in "$CONTENTS"/Resources/ClipSlop_ClipSlop.bundle/Contents/Resources/*.lproj; do
    if [ ! -d "$PROJECT_DIR/Sources/Resources/$(basename "$locale")" ]; then
        echo "Unexpected localization in release bundle: $locale" >&2
        exit 1
    fi
done
for locale in "$PROJECT_DIR"/Sources/Resources/*.lproj; do
    if [ ! -d "$CONTENTS/Resources/ClipSlop_ClipSlop.bundle/Contents/Resources/$(basename "$locale")" ]; then
        echo "Missing localization in release bundle: $locale" >&2
        exit 1
    fi
done
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Add :LSMinimumSystemVersion string 15.0" "$CONTENTS/Info.plist"

"$SCRIPT_DIR/generate-appintents-metadata.sh" --configuration release --arch arm64 --strict --output "$CONTENTS/Resources"
grep -q 'RunPromptOnClipboardIntent' "$CONTENTS/Resources/Metadata.appintents/extract.actionsdata"
"$SCRIPT_DIR/codesign.sh" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

mkdir "$STAGING"
ditto "$APP" "$STAGING/ClipSlop.app"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname ClipSlop -srcfolder "$STAGING" -format UDZO "$DMG"
shasum -a 256 "$DMG"
echo "Release: $DMG"
