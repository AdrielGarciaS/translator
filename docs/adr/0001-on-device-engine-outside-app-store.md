# On-device Engine outside the Mac App Store

- Translator uses Apple's Translation framework. Translation runs on the Mac after the user downloads language packs. This avoids API keys and sending selected text to a cloud translation service, but supports fewer languages than cloud Engines.
- Translator runs without the App Sandbox. The owner builds it locally. App Store distribution is not part of v1.
- The Trigger sends a simulated ⌘C to the active app. This requires Accessibility permission. It reads the copied Selection and restores the previous clipboard. We choose this method over Accessibility-only selection capture because support for selection attributes varies between apps.
- The Trigger uses a registered Carbon hotkey, not a global key logger. Translation setup uses a SwiftUI-hosted session so Apple can request missing language packs. macOS 26 is the agreed deployment target, although this session API also exists on macOS 15.
- Clipboard capture is best-effort. Secure fields and apps that do not support copying cannot provide a Selection. Concurrent clipboard changes and unusually slow copy operations remain risks. Do not describe capture as guaranteed in every app.
