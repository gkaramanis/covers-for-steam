#!/bin/bash
# Build "Covers for Steam.saver" into build/ and sign it with Developer ID.
# Pass --install to copy it to ~/Library/Screen Savers.
# SIGN_ID overrides the signing identity; SIGN_ID=- signs ad hoc.

set -euo pipefail
cd "$(dirname "$0")"

SIGN_ID="${SIGN_ID:-Developer ID Application: Georgios Karamanis (N4B5PD6UN5)}"
SAVER="build/Covers for Steam.saver"
rm -rf "$SAVER"
mkdir -p "$SAVER/Contents/MacOS"
cp saver/Info.plist "$SAVER/Contents/"

for arch in arm64 x86_64; do
  swiftc -O -module-name CoversForSteam \
    -target "$arch-apple-macos14" \
    -framework ScreenSaver \
    -Xlinker -bundle \
    -o "build/CoversForSteam-$arch" \
    saver/*.swift
done
lipo -create build/CoversForSteam-* -output "$SAVER/Contents/MacOS/CoversForSteam"
rm build/CoversForSteam-*

if [ "$SIGN_ID" = - ]; then
  codesign --force --sign - "$SAVER"
else
  codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$SAVER"
fi
codesign --verify --strict "$SAVER"
echo "Built and signed $SAVER"

if [ "${1:-}" = --install ]; then
  mkdir -p "$HOME/Library/Screen Savers"
  old="$HOME/Library/Screen Savers/Covers for Steam.saver"
  [ -e "$old" ] && /usr/bin/trash "$old"
  cp -R "$SAVER" "$HOME/Library/Screen Savers/"

  # legacyScreenSaver keeps the old code loaded until it exits; it
  # relaunches on demand.
  killall legacyScreenSaver 2>/dev/null || true
  echo "Installed to ~/Library/Screen Savers"
fi
