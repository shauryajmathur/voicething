#!/usr/bin/env bash
set -euo pipefail

CACHE_DIR="$HOME/Library/Application Support/VoiceThing/Clips"

rm -rf "$CACHE_DIR"
defaults delete com.voicething.app recents 2>/dev/null || true
defaults delete com.voicething.app favorites 2>/dev/null || true

echo "Cleared VoiceThing audio cache and saved recents/favorites."
