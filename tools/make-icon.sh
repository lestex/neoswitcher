#!/usr/bin/env bash
# Regenerates Resources/AppIcon.icns. Only needed when the mark in make-icon.swift changes.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SET="$ROOT/Resources/AppIcon.iconset"

rm -rf "$SET" && mkdir -p "$SET"
BIN="$(mktemp -d)/makeicon"
swiftc -target arm64-apple-macos14.0 -o "$BIN" "$ROOT/tools/make-icon.swift" -framework AppKit
"$BIN" "$SET"
iconutil -c icns "$SET" -o "$ROOT/Resources/AppIcon.icns"
[ "${KEEP_SET:-0}" = "1" ] || rm -rf "$SET"
echo "built $ROOT/Resources/AppIcon.icns"
