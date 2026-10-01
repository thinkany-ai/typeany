#!/bin/bash
# Renders the logo SVGs in assets/logo into the bundle's icon resources:
#   Sources/TypeAny/Resources/AppIcon.icns  — app icon (Dock, System Settings, onboarding)
#   Sources/TypeAny/Resources/TypeAny.pdf   — monochrome template icon (input menu, menu bar)
# Requires: brew install librsvg
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOGO="$ROOT/assets/logo"
RES="$ROOT/Sources/TypeAny/Resources"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

command -v rsvg-convert >/dev/null || { echo "rsvg-convert not found: brew install librsvg"; exit 1; }

ICONSET="$TMP/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  rsvg-convert -w "$size" "$LOGO/typeany-icon.svg" -o "$ICONSET/icon_${size}x${size}.png"
  rsvg-convert -w "$((size * 2))" "$LOGO/typeany-icon.svg" -o "$ICONSET/icon_${size}x${size}@2x.png"
done
iconutil -c icns "$ICONSET" -o "$RES/AppIcon.icns"

rsvg-convert -f pdf "$LOGO/typeany-mark.svg" -o "$RES/TypeAny.pdf"
echo "Icons written to $RES"
