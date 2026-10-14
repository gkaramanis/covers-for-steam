#!/bin/bash
# Build "Covers for Steam.saver" into build/. Pass --install to copy it to
# ~/Library/Screen Savers.

set -euo pipefail
cd "$(dirname "$0")"

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

codesign --force --sign - "$SAVER"
echo "Built $SAVER"

if [ "${1:-}" = --install ]; then
  mkdir -p "$HOME/Library/Screen Savers"
  old="$HOME/Library/Screen Savers/Covers for Steam.saver"
  [ -e "$old" ] && /usr/bin/trash "$old"
  cp -R "$SAVER" "$HOME/Library/Screen Savers/"
  echo "Installed to ~/Library/Screen Savers"
fi
