#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ICONSET="$ROOT/DisplayLuminance/Assets.xcassets/AppIcon.appiconset"
APP="$ROOT/build/Build/Products/Debug/DisplayLuminance.app"

echo "Generating icons..."
swift "$ROOT/Scripts/generate-app-icon.swift" "$ICONSET"

echo "Verifying icon dimensions..."
for spec in "icon_16x16.png:16" "icon_16x16@2x.png:32" "icon_512x512@2x.png:1024"; do
  file="${spec%%:*}"
  expected="${spec##*:}"
  actual=$(sips -g pixelWidth "$ICONSET/$file" 2>/dev/null | awk '/pixelWidth/ {print $2}')
  if [[ "$actual" != "$expected" ]]; then
    echo "ERROR: $file is ${actual}px, expected ${expected}px" >&2
    exit 1
  fi
done

echo "Building app..."
xcodebuild -project "$ROOT/DisplayLuminance.xcodeproj" \
  -scheme DisplayLuminance \
  -configuration Debug \
  -derivedDataPath "$ROOT/build" \
  clean build >/dev/null

echo "Refreshing Launch Services icon cache..."
touch "$APP"
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f -R -trusted "$APP"

echo "Done. Open with:"
echo "open \"$APP\""
