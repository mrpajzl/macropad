#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release "$@"
BIN_DIR=$(swift build -c release "$@" --show-bin-path)
APP=dist/MacroPad.app
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/MacroPad" "$APP/Contents/MacOS/MacroPad"
cp Info.plist "$APP/Contents/"
cp Artwork/MacroPadIcon.icns "$APP/Contents/Resources/MacroPadIcon.icns"
cp Firmware/macropad-learn.uf2 Firmware/firmware.json "$APP/Contents/Resources/"
codesign --force --deep --sign - "$APP"
echo "OK → $APP"
