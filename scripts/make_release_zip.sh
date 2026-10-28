#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bash "$ROOT_DIR/scripts/package_app.sh"
bash "$ROOT_DIR/scripts/build_audio_driver.sh"
pkgbuild --component "$ROOT_DIR/.build/VoiceThingAudio.driver" \
    --install-location /Library/Audio/Plug-Ins/HAL \
    --identifier com.voicething.audio.installer --version 1.0.0 \
    --scripts "$ROOT_DIR/Driver/installer" "$ROOT_DIR/dist/VoiceThingMicrophone.pkg"
(cd "$ROOT_DIR/dist" && shasum -a 256 VoiceThing.zip VoiceThingMicrophone.pkg > SHA256SUMS.txt)
