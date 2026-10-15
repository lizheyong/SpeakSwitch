#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build --build-system native -c release
bin_dir="$(swift build --build-system native -c release --show-bin-path)"
app_dir="$PWD/dist/Voice Switch.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$bin_dir/VoiceSwitch" "$app_dir/Contents/MacOS/VoiceSwitch"
cp Resources/Info.plist "$app_dir/Contents/Info.plist"
xcrun swift scripts/make-icon.swift "$app_dir/Contents/Resources/AppIcon.icns"
codesign --force --sign - --identifier app.voiceswitch.mac "$app_dir"
ditto -c -k --sequesterRsrc --keepParent "$app_dir" "dist/Voice-Switch-$(uname -m).zip"
echo "Built: $app_dir"

if [[ "${1:-}" == "--install" ]]; then
    mkdir -p "$HOME/Applications"
    ditto "$app_dir" "$HOME/Applications/Voice Switch.app"
    echo "Installed: $HOME/Applications/Voice Switch.app"
fi
