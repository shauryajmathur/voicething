# VoiceThing for macOS

Open a chat, press Option–Space, choose a sound, and press Enter. In WhatsApp Web, VoiceThing copies and pastes the audio file into the chat; review the attachment and press Send. Other chats use VoiceThing Microphone: it starts the chat’s recorder, plays the selected audio through the virtual microphone, stops, and sends. The previous microphone is restored afterward.

The microphone route is used for other browser chats and native apps. WhatsApp Web is detected from the active page URL in supported browsers, including Zen, Firefox, Safari, Chrome, Edge, Brave, Arc, and Opera. The destination must expose accessible record, stop, and send buttons. Apps with unsupported controls or press-and-hold recorders need a dedicated adapter; VoiceThing reports an error when it cannot find a recorder. Use the system default microphone in the destination app. Browser speech processing can suppress music and sound effects.

## Setup

The welcome screen opens on first launch. Allow Accessibility access to paste audio and operate chat controls. For the microphone route, install the VoiceThing Microphone driver from the release’s `VoiceThingMicrophone.pkg`. Click the shortcut badge in the search bar to record a different global shortcut. Settings includes the same shortcut control. The welcome screen can be reopened from the menu.

## Audio and storage

Downloaded sounds are normalized to M4A in small chunks off the main thread. Explicitly saved clips and microphone recordings are available in Audio Recordings. A microphone permission prompt appears only if you choose to make a recording.

Keep sounds on this Mac is off by default. The temporary cache is capped at 64 MB and files older than 24 hours are removed on launch or when preparing a clip. If enabled, the retained sound cache is capped at 160 MB and favorites and history persist. Turning retention off clears saved sound history and the retained cache. Recordings you explicitly save remain until deleted.

## Build and test

```sh
swift test
bash scripts/package_app.sh
open VoiceThing.app
```

Packaging builds a universal macOS 14+ application and writes `dist/VoiceThing.zip`. Packaging uses the available persistent Apple signing identity. Set `CODE_SIGN_IDENTITY` explicitly if more than one is installed. Public distribution needs Developer ID signing and notarization.
