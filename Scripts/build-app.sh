#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

check_drive() {
    if ! /sbin/mount | /usr/bin/grep -F ' on /Volumes/MyPassport (' >/dev/null ||
        [[ ! -d /Volumes/MyPassport || ! -r /Volumes/MyPassport || ! -x /Volumes/MyPassport ]]; then
        echo 'Connect MyPassport before building Harold.' >&2
        exit 1
    fi
}

configuration="${1:-debug}"
case "$configuration" in
    debug|release) ;;
    *) echo 'Usage: Scripts/build-app.sh [debug|release]' >&2; exit 2 ;;
esac

check_drive
mkdir -p .build/module-cache
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$CLANG_MODULE_CACHE_PATH"

swift_flags=(--configuration "$configuration")
if [[ "${HAROLD_SWIFTPM_DISABLE_SANDBOX:-0}" == 1 ]]; then
    swift_flags+=(--disable-sandbox)
fi

check_drive
swift build "${swift_flags[@]}"

check_drive
bin_path="$(swift build "${swift_flags[@]}" --show-bin-path)"

bundle="$PWD/dist/Harold.app"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
cp "$bin_path/Harold" "$bundle/Contents/MacOS/Harold"
cp AppBundle/Info.plist "$bundle/Contents/Info.plist"
cp -R "$bin_path/Harold_Harold.bundle" "$bundle/Contents/Resources/"
cp AppBundle/Harold.icns "$bundle/Contents/Resources/Harold.icns"
/usr/bin/codesign --force --sign - "$bundle"
echo "$bundle"
