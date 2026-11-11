#!/bin/bash
# Exercise installation without Xcode, Keychain access, or launching an app.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/project/scripts" "$tmp/home/Applications/Translator.app/Contents/MacOS"
cp "$root/scripts/install.sh" "$tmp/project/scripts/"

cat > "$tmp/mock" <<'MOCK'
#!/bin/bash
set -euo pipefail
case "$(basename "$0")" in
    xcodegen|xcrun|codesign|open) exit 0 ;;
    pgrep)
        [[ "${INSTALL_TEST_RUNNING:-0}" == 1 || -e "$HOME/.translator-test-running" ]]
        ;;
    xcodebuild)
        [[ "${1:-}" != -version ]] || exit 0
        [[ "${INSTALL_TEST_FAIL_BUILD:-0}" != 1 ]] || exit 1
        mkdir -p build/Build/Products/Release/Translator.app/Contents/MacOS
        printf 'new binary' > build/Build/Products/Release/Translator.app/Contents/MacOS/Translator
        if [[ "${INSTALL_TEST_START_DURING_BUILD:-0}" == 1 ]]; then
            touch "$HOME/.translator-test-running"
        fi
        ;;
    mv)
        if [[ "${INSTALL_TEST_FAIL_MOVE:-0}" == 1 && "$1" == */.translator-install*/Translator.app ]]; then
            exit 1
        fi
        exec /bin/mv "$@"
        ;;
esac
MOCK
chmod +x "$tmp/mock"
for command in xcodegen xcrun xcodebuild codesign open pgrep mv; do
    ln -s "$tmp/mock" "$tmp/bin/$command"
done
export HOME="$tmp/home" PATH="$tmp/bin:$PATH"
app="$HOME/Applications/Translator.app"
printf 'old debug library' > "$app/Contents/MacOS/Translator.debug.dylib"

bash "$tmp/project/scripts/install.sh" >/dev/null
[[ -f "$app/Contents/MacOS/Translator" ]]
if [[ -e "$app/Contents/MacOS/Translator.debug.dylib" ]]; then
    echo 'FAIL: updating retains a stale Debug library' >&2
    exit 1
fi
echo 'PASS: update replaces the whole app bundle'

printf 'existing install' > "$app/keep-me"
if INSTALL_TEST_FAIL_BUILD=1 bash "$tmp/project/scripts/install.sh" >/dev/null 2>&1; then
    echo 'FAIL: build failure must stop installation' >&2
    exit 1
fi
[[ -f "$app/keep-me" ]]
echo 'PASS: build failure keeps the existing app'

if INSTALL_TEST_FAIL_MOVE=1 bash "$tmp/project/scripts/install.sh" >/dev/null 2>&1; then
    echo 'FAIL: install failure must return an error' >&2
    exit 1
fi
[[ -f "$app/keep-me" ]]
echo 'PASS: failed installation restores the existing app'

if INSTALL_TEST_RUNNING=1 bash "$tmp/project/scripts/install.sh" >/dev/null 2>&1; then
    echo 'FAIL: running app must block installation' >&2
    exit 1
fi
[[ -f "$app/keep-me" ]]
echo 'PASS: running app is not replaced'

if INSTALL_TEST_START_DURING_BUILD=1 bash "$tmp/project/scripts/install.sh" >/dev/null 2>&1; then
    echo 'FAIL: app started during build must block installation' >&2
    exit 1
fi
[[ -f "$app/keep-me" ]]
rm "$HOME/.translator-test-running"
echo 'PASS: app started during build is not replaced'

mkdir "$HOME/Applications/.translator-install"
printf 'another installer' > "$HOME/Applications/.translator-install/keep-lock"
if bash "$tmp/project/scripts/install.sh" >/dev/null 2>&1; then
    echo 'FAIL: overlapping installation must be blocked' >&2
    exit 1
fi
[[ -f "$app/keep-me" && -f "$HOME/Applications/.translator-install/keep-lock" ]]
echo 'PASS: an existing install lock is respected'
