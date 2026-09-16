#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release "$@"
BIN_DIR=$(swift build -c release "$@" --show-bin-path)
APP=dist/MacroPad.app
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/MacroPad" "$APP/Contents/MacOS/MacroPad"
cp Info.plist "$APP/Contents/"
[ -f AppIcon.icns ] && cp AppIcon.icns "$APP/Contents/Resources/"
codesign --force --deep --sign - "$APP"
echo "OK → $APP"
