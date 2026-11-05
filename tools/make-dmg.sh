#!/usr/bin/env bash
# Packs NeoSwitcher.app into a drag-to-Applications disk image.
# Usage: tools/make-dmg.sh [output.dmg]   (run ./build.sh first)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/NeoSwitcher.app"
DMG="${1:-$ROOT/NeoSwitcher.dmg}"

[ -d "$APP" ] || { echo "no bundle at $APP — run ./build.sh first" >&2; exit 1; }

STAGE="$(mktemp -d)/NeoSwitcher"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"   # the drag target

rm -f "$DMG"
hdiutil create -volname NeoSwitcher -srcfolder "$STAGE" -ov -format UDZO -quiet "$DMG"
rm -rf "$(dirname "$STAGE")"

echo "built $DMG ($(du -h "$DMG" | cut -f1))"
