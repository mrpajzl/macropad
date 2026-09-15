#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release
APP=dist/MacroPad.app
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/MacroPad "$APP/Contents/MacOS/MacroPad"
cp Info.plist "$APP/Contents/"
[ -f AppIcon.icns ] && cp AppIcon.icns "$APP/Contents/Resources/"
codesign --force --deep --sign - "$APP" 2>/dev/null
echo "OK → $APP"
