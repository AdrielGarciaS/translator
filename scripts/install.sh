#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "Install XcodeGen first: brew install xcodegen" >&2
    exit 1
fi
if ! xcrun --find swift >/dev/null 2>&1 || ! xcodebuild -version >/dev/null 2>&1; then
    echo "Install full Xcode, open it once, and select it with xcode-select." >&2
    exit 1
fi
if pgrep -x Translator >/dev/null; then
    echo "Quit Translator from its gear menu before installing an update." >&2
    exit 1
fi

mkdir -p "$HOME/Applications"
# Stage a complete bundle. Overlaying Debug and Release apps retains stale dylibs.
staging="$HOME/Applications/.translator-install"
if ! mkdir "$staging"; then
    echo "Another installation is active, or an interrupted installation needs recovery: $staging" >&2
    exit 1
fi
trap '
    if [[ -e "$staging/previous.app" ]]; then
        echo "Previous app retained at: $staging/previous.app" >&2
    else
        rm -rf "$staging"
    fi
' EXIT
# A local build needs no paid Apple developer account or shared certificate.
# Keep an existing local certificate by setting TRANSLATOR_SIGNING_IDENTITY.
signing_identity="${TRANSLATOR_SIGNING_IDENTITY:--}"
xcodegen generate
xcodebuild -scheme Translator -configuration Release -derivedDataPath build \
    CODE_SIGN_STYLE=Manual "CODE_SIGN_IDENTITY=$signing_identity" build

app="build/Build/Products/Release/Translator.app"
codesign --verify --deep --strict "$app"
ditto "$app" "$staging/Translator.app"
codesign --verify --deep --strict "$staging/Translator.app"
if pgrep -x Translator >/dev/null; then
    echo "Quit Translator from its gear menu before installing an update." >&2
    exit 1
fi
if [[ -e "$HOME/Applications/Translator.app" ]]; then
    mv "$HOME/Applications/Translator.app" "$staging/previous.app"
fi
if ! mv "$staging/Translator.app" "$HOME/Applications/Translator.app"; then
    if [[ -e "$staging/previous.app" ]]; then
        mv "$staging/previous.app" "$HOME/Applications/Translator.app"
    fi
    exit 1
fi
codesign --verify --deep --strict "$HOME/Applications/Translator.app"
rm -rf "$staging/previous.app"
open "$HOME/Applications/Translator.app"
printf "\nInstalled: %s/Applications/Translator.app\n" "$HOME"
echo "Translator appears in the menu bar, not the Dock."
