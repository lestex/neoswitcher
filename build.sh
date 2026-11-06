#!/usr/bin/env bash
# Builds NeoSwitcher.app (release, arm64) and codesigns it.
#
#   CODESIGN_IDENTITY="NeoSwitcher Dev" ./build.sh     # stable identity (recommended)
#   ALLOW_ADHOC=1 ./build.sh                           # ad-hoc: TCC grants reset on every build
#   NEOSWITCHER_VERSION=1.2.3 ...                      # stamps the bundle version (used by CI)
set -euo pipefail
cd "$(dirname "$0")"

APP="NeoSwitcher.app"
ID="${CODESIGN_IDENTITY:-}"

if [[ -z "$ID" ]]; then
  if [[ "${ALLOW_ADHOC:-0}" == "1" ]]; then
    ID="-"
    echo "warning: ad-hoc signature. macOS ties Accessibility/Input Monitoring grants to the" >&2
    echo "         code signature, and ad-hoc signatures change on every build, so you will" >&2
    echo "         have to re-grant permissions after each rebuild." >&2
  else
    echo "error: set CODESIGN_IDENTITY to a stable code-signing identity (see README)," >&2
    echo "       or ALLOW_ADHOC=1 to sign ad-hoc." >&2
    exit 1
  fi
fi

swift build -c release --arch arm64
BIN="$(swift build -c release --arch arm64 --show-bin-path)/neoswitcher"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/neoswitcher"
mkdir -p "$APP/Contents/Resources"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp Resources/Info.plist "$APP/Contents/Info.plist"
if [[ -n "${NEOSWITCHER_VERSION:-}" ]]; then
  plutil -replace CFBundleShortVersionString -string "$NEOSWITCHER_VERSION" "$APP/Contents/Info.plist"
  plutil -replace CFBundleVersion -string "$NEOSWITCHER_VERSION" "$APP/Contents/Info.plist"
fi

codesign --force --options runtime --identifier com.lestex.neoswitcher --sign "$ID" "$APP"
codesign --verify --strict "$APP"
echo "Built $APP (signed with: ${ID/#-/ad-hoc})"
