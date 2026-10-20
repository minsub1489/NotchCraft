#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration=release
if [[ "${1:-}" == "--debug" ]]; then configuration=debug; fi
swift build -c "$configuration"
bin_dir="$(swift build -c "$configuration" --show-bin-path)"
app_path="$PWD/build/NotchCraft.app"
# Recreate only this generated artifact so stale debug/test resources cannot ship.
if [[ -d "$app_path" ]]; then rm -rf "$app_path"; fi
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$bin_dir/NotchCraft" "$app_path/Contents/MacOS/NotchCraft"
cp Support/Info.plist "$app_path/Contents/Info.plist"
ditto "$bin_dir/NotchCraft_NotchCraft.bundle" "$app_path/Contents/Resources/NotchCraft_NotchCraft.bundle"
if [[ -f Sources/NotchCraft/Resources/AppIcon.icns ]]; then cp Sources/NotchCraft/Resources/AppIcon.icns "$app_path/Contents/Resources/"; fi
codesign --force --sign - --entitlements Support/NotchCraft.entitlements "$app_path"
printf '%s\n' "$app_path"
