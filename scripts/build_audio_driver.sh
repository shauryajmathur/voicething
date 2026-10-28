#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DRIVER="$ROOT_DIR/.build/VoiceThingAudio.driver"
mkdir -p "$DRIVER/Contents/MacOS" "$DRIVER/Contents/Resources/en.lproj"
xcrun clang -isysroot "$(xcrun --sdk macosx --show-sdk-path)" -std=c11 -O2 -arch arm64 -arch x86_64 -mmacosx-version-min=14.0 \
  -bundle -framework CoreAudio -framework CoreFoundation \
  "$ROOT_DIR/Driver/VoiceThingAudio.c" -o "$DRIVER/Contents/MacOS/VoiceThingAudio"
cp "$ROOT_DIR/Driver/Info.plist" "$DRIVER/Contents/Info.plist"
cp "$ROOT_DIR/Driver/en.lproj/Localizable.strings" "$DRIVER/Contents/Resources/en.lproj/"
cp "$ROOT_DIR/Driver/LICENSE.txt" "$DRIVER/Contents/Resources/"
codesign --force --sign "${CODE_SIGN_IDENTITY:--}" "$DRIVER"
