# VoiceThing

Native macOS menu-bar utility for searching MyInstants meme audio clips and pasting them into the chat app that was focused before the popup opened.

## Requirements

- macOS 14+
- No API key required

## Run

Open `VoiceThing.app`.

The app runs as a menu-bar item and hides from the Dock. Press `Option+Space` or click the waveform menu-bar icon to open the popup.

You can change the global shortcut in VoiceThing settings.

## First Use

1. macOS will ask for Accessibility permission the first time the app tries to paste into another app.
2. Open WhatsApp Desktop or another messenger, focus a message box, press `Option+Space`, search, and select an audio clip.

VoiceThing copies the audio file to the pasteboard and sends `Cmd+V` to the previously focused app. It does not press Enter or send the message.

Downloaded clips are normalized before sending so very loud and very quiet meme sounds land closer to the same volume. The original source file is kept in cache, and the sent file is stored as a normalized M4A.

## Accessibility Troubleshooting

If macOS says Accessibility is still needed after you already enabled it, remove VoiceThing from System Settings, reopen the app, and add it again.

## Clear Local Cache

VoiceThing stores downloaded clips and normalized send-ready files under `~/Library/Application Support/VoiceThing/Clips` and saves recents/favorites in `com.voicething.app` preferences.

Delete that folder if you want to fully reset downloaded clips.
