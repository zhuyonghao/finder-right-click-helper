#!/bin/bash
# Build a self-contained macOS app with its embedded Finder Sync extension.
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-release}"
OUTPUT_DIR="${OUTPUT_DIR:-$PROJECT_ROOT/build}"
APP_GROUP_ID="${APP_GROUP_ID:-group.com.youjianzhushou.shared}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"
TEAM_ID="${TEAM_ID:-}"
SETTINGS_STORAGE="${SETTINGS_STORAGE:-preferences}"
PLIST_BUDDY=/usr/libexec/PlistBuddy

if [[ "$CONFIGURATION" != release && "$CONFIGURATION" != debug ]]; then
    echo "CONFIGURATION must be release or debug." >&2
    exit 1
fi
if [[ "$SETTINGS_STORAGE" != preferences && "$SETTINGS_STORAGE" != app-group ]]; then
    echo "SETTINGS_STORAGE must be preferences or app-group." >&2
    exit 1
fi
if [[ "$SETTINGS_STORAGE" == app-group && "$SIGNING_IDENTITY" == - ]]; then
    echo "App Group storage requires a developer signature. Use preferences for local ad-hoc builds." >&2
    exit 1
fi
if [[ ! "$APP_GROUP_ID" =~ ^[A-Za-z0-9.-]+$ ]]; then
    echo "APP_GROUP_ID may contain only letters, numbers, dots and hyphens." >&2
    exit 1
fi
if [[ -n "$TEAM_ID" && ! "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]]; then
    echo "TEAM_ID must be the 10-character Apple Developer team identifier." >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/finderhelper-build.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT
APP_PATH="$STAGING_DIR/右键助手.app"
EXTENSION_PATH="$APP_PATH/Contents/PlugIns/FinderExtension.appex"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
mkdir -p "$EXTENSION_PATH/Contents/MacOS"

echo "Building the app ($CONFIGURATION)…"
swift build --package-path "$PROJECT_ROOT" --configuration "$CONFIGURATION"
BINARY_DIR="$(swift build --package-path "$PROJECT_ROOT" --configuration "$CONFIGURATION" --show-bin-path)"
cp "$BINARY_DIR/FinderHelper" "$APP_PATH/Contents/MacOS/FinderHelper"
cp "$PROJECT_ROOT/Resources/App-Info.plist" "$APP_PATH/Contents/Info.plist"
cp "$PROJECT_ROOT/Resources/FinderExtension-Info.plist" "$EXTENSION_PATH/Contents/Info.plist"

echo "Building the Finder Sync extension…"
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
OPTIMIZATION=-O
if [[ "$CONFIGURATION" == debug ]]; then OPTIMIZATION=-Onone; fi
swiftc -swift-version 5 -application-extension -parse-as-library -emit-executable "$OPTIMIZATION" \
    -Xlinker -e -Xlinker _NSExtensionMain \
    -sdk "$SDK_PATH" -target "$(uname -m)-apple-macosx14.0" \
    -module-name FinderExtension -framework FinderSync -framework Cocoa \
    "$PROJECT_ROOT"/Sources/FinderHelperCore/*.swift \
    "$PROJECT_ROOT"/Sources/FinderExtension/*.swift \
    -o "$EXTENSION_PATH/Contents/MacOS/FinderExtension"

echo "Rendering the app icon…"
swift "$PROJECT_ROOT/scripts/generate-icon.swift" "$STAGING_DIR/AppIcon.iconset"
iconutil --convert icns "$STAGING_DIR/AppIcon.iconset" --output "$APP_PATH/Contents/Resources/AppIcon.icns"

cp "$PROJECT_ROOT/Resources/App.entitlements" "$STAGING_DIR/App.entitlements"
cp "$PROJECT_ROOT/Resources/FinderExtension.entitlements" "$STAGING_DIR/FinderExtension.entitlements"
if [[ "$SETTINGS_STORAGE" == app-group ]]; then
    for BUNDLE in "$APP_PATH" "$EXTENSION_PATH"; do
        "$PLIST_BUDDY" -c 'Delete :SharedPreferenceDomain' "$BUNDLE/Contents/Info.plist"
        "$PLIST_BUDDY" -c "Add :AppGroupIdentifier string $APP_GROUP_ID" "$BUNDLE/Contents/Info.plist"
    done
    "$PLIST_BUDDY" -c 'Delete :com.apple.security.temporary-exception.shared-preference.read-only' "$STAGING_DIR/FinderExtension.entitlements"
fi
for ENTITLEMENTS in "$STAGING_DIR/App.entitlements" "$STAGING_DIR/FinderExtension.entitlements"; do
    if [[ "$SETTINGS_STORAGE" == app-group ]]; then
        "$PLIST_BUDDY" -c 'Add :com.apple.security.application-groups array' "$ENTITLEMENTS"
        "$PLIST_BUDDY" -c "Add :com.apple.security.application-groups:0 string $APP_GROUP_ID" "$ENTITLEMENTS"
    fi
    if [[ -n "$TEAM_ID" ]]; then
        "$PLIST_BUDDY" -c "Add :com.apple.developer.team-identifier string $TEAM_ID" "$ENTITLEMENTS"
    fi
done

# Registered group.* identifiers may need matching provisioning profiles.
if [[ -n "${APP_PROVISIONING_PROFILE:-}" ]]; then
    cp "$APP_PROVISIONING_PROFILE" "$APP_PATH/Contents/embedded.provisionprofile"
fi
if [[ -n "${EXTENSION_PROVISIONING_PROFILE:-}" ]]; then
    cp "$EXTENSION_PROVISIONING_PROFILE" "$EXTENSION_PATH/Contents/embedded.provisionprofile"
fi

SIGN_OPTIONS=(--force --sign "$SIGNING_IDENTITY" --timestamp=none)
if [[ "$SIGNING_IDENTITY" != - ]]; then
    SIGN_OPTIONS+=(--options runtime)
fi
codesign "${SIGN_OPTIONS[@]}" --entitlements "$STAGING_DIR/FinderExtension.entitlements" "$EXTENSION_PATH"
codesign "${SIGN_OPTIONS[@]}" --entitlements "$STAGING_DIR/App.entitlements" "$APP_PATH"
codesign --verify --strict --deep --verbose=2 "$APP_PATH"

DESTINATION="$OUTPUT_DIR/右键助手.app"
if [[ -e "$DESTINATION" ]]; then rm -rf "$DESTINATION"; fi
ditto "$APP_PATH" "$DESTINATION"
echo "Built: $DESTINATION"
if [[ "$SIGNING_IDENTITY" == - ]]; then
    echo "Local ad-hoc signature. Settings use the host's preferences; the extension has scoped read-only access."
fi
