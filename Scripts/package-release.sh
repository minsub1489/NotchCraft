#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./Scripts/build-app.sh
app_path="$PWD/build/NotchCraft.app"
if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
    codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" --entitlements Support/NotchCraft.entitlements "$app_path"
    if [[ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
        ditto -c -k --keepParent "$app_path" build/NotchCraft-notarize.zip
        xcrun notarytool submit build/NotchCraft-notarize.zip --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" --wait
        xcrun stapler staple "$app_path"
    fi
fi
ditto -c -k --keepParent "$app_path" build/NotchCraft-0.1.0-macos.zip
