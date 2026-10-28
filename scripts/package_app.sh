#!/usr/bin/env bash
set -euo pipefail
export COPYFILE_DISABLE=1
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
if pgrep -x VoiceThing >/dev/null; then
    printf 'Quit VoiceThing before packaging. Replacing a running executable invalidates its macOS permission identity.\n' >&2
    exit 1
fi
SIGN_IDENTITY="${CODE_SIGN_IDENTITY:-}"
if [ -z "$SIGN_IDENTITY" ]; then
    IDENTITIES="$(security find-identity -v -p codesigning | sed -nE '/"(Apple Development:|Developer ID Application:)/s/^[[:space:]]*[0-9]+\) ([A-F0-9]+).*/\1/p')"
    IDENTITY_COUNT="$(printf '%s\n' "$IDENTITIES" | sed '/^$/d' | wc -l | tr -d ' ')"
    if [ "$IDENTITY_COUNT" != 1 ]; then
        printf 'Set CODE_SIGN_IDENTITY to a persistent Apple signing identity. Ad-hoc signing requires an explicit CODE_SIGN_IDENTITY=-.\n' >&2
        exit 1
    fi
    SIGN_IDENTITY="$IDENTITIES"
fi
SWIFT_FLAGS=(-c release --arch arm64 --arch x86_64)
swift build "${SWIFT_FLAGS[@]}"
BIN_DIR="$(swift build "${SWIFT_FLAGS[@]}" --show-bin-path)"
APP_DIR="$ROOT_DIR/VoiceThing.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/VoiceThing" "$APP_DIR/Contents/MacOS/VoiceThing"
cp Resources/VoiceThing.icns "$APP_DIR/Contents/Resources/VoiceThing.icns"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"
for bundle in "$BIN_DIR"/*.bundle; do
    if [ -d "$bundle" ]; then
        rm -rf "$APP_DIR/Contents/Resources/$(basename "$bundle")"
        ditto "$bundle" "$APP_DIR/Contents/Resources/$(basename "$bundle")"
    fi
done
chmod +x "$APP_DIR/Contents/MacOS/VoiceThing"

rm -f "$APP_DIR/Contents/Resources/VoiceThingMicrophone.pkg"
find "$APP_DIR/Contents/Resources" -name InstagramVoice.js -delete
codesign --force --sign "$SIGN_IDENTITY" --options runtime --entitlements Resources/VoiceThing.entitlements "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"
mkdir -p dist
ditto --norsrc --noextattr -c -k --keepParent "$APP_DIR" dist/VoiceThing.zip
printf 'Built %s\n' "$APP_DIR"
