#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/VoiceThing.app"
DESTINATION="/Applications/VoiceThing.app"
if pgrep -x VoiceThing >/dev/null; then
    printf 'Quit VoiceThing before installing. The running copy must exit before its signed files are replaced.\n' >&2
    exit 1
fi
codesign --verify --deep --strict "$APP_DIR"
STAGING="$(mktemp -d /Applications/.voicething-install.XXXXXX)"
trap 'rm -rf "$STAGING"' EXIT
ditto "$APP_DIR" "$STAGING/VoiceThing.app"
codesign --verify --deep --strict "$STAGING/VoiceThing.app"
if pgrep -x VoiceThing >/dev/null; then
    printf 'VoiceThing opened during installation. Quit it and retry.\n' >&2
    exit 1
fi
if [ -d "$DESTINATION" ]; then
    mkdir -p "$ROOT_DIR/.build/install-backup"
    BACKUP="$ROOT_DIR/.build/install-backup/VoiceThing-$(date +%Y%m%d-%H%M%S).app"
    mv "$DESTINATION" "$BACKUP"
fi
mv "$STAGING/VoiceThing.app" "$DESTINATION"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DESTINATION"
open "$DESTINATION"
