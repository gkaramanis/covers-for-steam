#!/bin/bash
# Build "Covers for Steam.saver" into build/ and sign it with Developer ID.
# Pass --install to copy it to ~/Library/Screen Savers, --release to notarize
# it (keychain profile stripes-notary, same team) and zip it, or --pkg to do
# that and also build a signed, notarized installer package.
# SIGN_ID overrides the signing identity; SIGN_ID=- signs ad hoc.

set -euo pipefail
cd "$(dirname "$0")"

SIGN_ID="${SIGN_ID:-Developer ID Application: Georgios Karamanis (N4B5PD6UN5)}"
SAVER="build/Covers for Steam.saver"
rm -rf "$SAVER"
mkdir -p "$SAVER/Contents/MacOS" "$SAVER/Contents/Resources"
cp saver/Info.plist "$SAVER/Contents/"

# System Settings reads the thumbnail only from a TIFF holding both resolutions.
tiffutil -cathidpicheck saver/Resources/thumbnail.png saver/Resources/thumbnail@2x.png \
  -out "$SAVER/Contents/Resources/thumbnail.tiff" >/dev/null

# The Command Line Tools lack the Intel slice of a Swift support library; a full Xcode has it.
if [ -z "${DEVELOPER_DIR:-}" ] && ! xcode-select -p | grep -q '\.app/'; then
  for x in /Applications/Xcode.app /Applications/Xcode-beta.app; do
    if [ -d "$x" ]; then export DEVELOPER_DIR="$x/Contents/Developer"; break; fi
  done
fi

for arch in arm64 x86_64; do
  xcrun swiftc -O -module-name CoversForSteam \
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

if [ "${1:-}" = --release ] || [ "${1:-}" = --pkg ]; then
  # notarytool needs an archive; the stapled bundle is zipped again for release.
  version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' saver/Info.plist)
  zip="build/Covers-for-Steam-$version.zip"
  ditto -c -k --keepParent "$SAVER" "$zip"
  xcrun notarytool submit "$zip" --keychain-profile stripes-notary --wait
  xcrun stapler staple "$SAVER"
  rm "$zip"
  ditto -c -k --keepParent "$SAVER" "$zip"
  xcrun stapler validate "$SAVER"
  echo "Notarized: $zip"
fi

if [ "${1:-}" = --pkg ]; then
  work=build/pkg
  rm -rf "$work"
  mkdir -p "$work/root" "$work/scripts"
  ditto "$SAVER" "$work/root/Covers for Steam.saver"
  cp pkg/postinstall "$work/scripts/"

  # Not relocatable, so the installer never writes over a copy it finds somewhere else.
  pkgbuild --analyze --root "$work/root" "$work/component.plist" >/dev/null
  plutil -replace 0.BundleIsRelocatable -bool NO "$work/component.plist"
  pkgbuild --root "$work/root" --component-plist "$work/component.plist" \
    --scripts "$work/scripts" --identifier is.karaman.covers-for-steam --version "$version" \
    --install-location "/Library/Screen Savers" "$work/CoversForSteam.pkg"

  # The user picks this Mac or only their own account; the second needs no admin password.
  cat > "$work/distribution.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
    <title>Covers for Steam</title>
    <domains enable_anywhere="false" enable_currentUserHome="true" enable_localSystem="true"/>
    <options customize="never" require-scripts="false" hostArchitectures="arm64,x86_64"/>
    <volume-check><allowed-os-versions><os-version min="14.0"/></allowed-os-versions></volume-check>
    <choices-outline><line choice="default"/></choices-outline>
    <choice id="default" title="Covers for Steam"><pkg-ref id="is.karaman.covers-for-steam"/></choice>
    <pkg-ref id="is.karaman.covers-for-steam" version="$version">CoversForSteam.pkg</pkg-ref>
</installer-gui-script>
EOF

  pkg="build/Covers-for-Steam-$version.pkg"
  productbuild --distribution "$work/distribution.xml" --package-path "$work" \
    --sign "Developer ID Installer: Georgios Karamanis (N4B5PD6UN5)" --timestamp "$pkg"
  rm -rf "$work"
  xcrun notarytool submit "$pkg" --keychain-profile stripes-notary --wait
  xcrun stapler staple "$pkg"
  spctl -a -vv -t install "$pkg"
  echo "Notarized: $pkg"
fi

if [ "${1:-}" = --install ]; then
  mkdir -p "$HOME/Library/Screen Savers"
  old="$HOME/Library/Screen Savers/Covers for Steam.saver"
  [ -e "$old" ] && /usr/bin/trash "$old"
  cp -R "$SAVER" "$HOME/Library/Screen Savers/"

  # legacyScreenSaver keeps the old code loaded until it exits; it
  # relaunches on demand.
  killall legacyScreenSaver 2>/dev/null || true
  echo "Installed to ~/Library/Screen Savers"

  # A copy from the installer in /Library loads instead of this one.
  if [ -e "/Library/Screen Savers/Covers for Steam.saver" ]; then
    echo "Warning: /Library/Screen Savers/Covers for Steam.saver loads instead of this build." >&2
    echo "Remove it with: sudo mv \"/Library/Screen Savers/Covers for Steam.saver\" ~/.Trash/" >&2
  fi
fi
