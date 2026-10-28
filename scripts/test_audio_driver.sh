#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
mkdir -p .build
SDK="$(xcrun --sdk macosx --show-sdk-path)"
xcrun clang -isysroot "$SDK" -std=c11 -Wall -Wextra -Werror Driver/VoiceThingRingTests.c -o .build/VoiceThingRingTests
.build/VoiceThingRingTests
xcrun clang -isysroot "$SDK" -std=c11 -O2 -framework CoreAudio -framework CoreFoundation Driver/VoiceThingDriverTests.c -o .build/VoiceThingDriverTests
.build/VoiceThingDriverTests
