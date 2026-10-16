# Covers for Steam

A macOS screensaver that shows the cover art from your Steam library, read
straight from Steam's local cache. Pick Wall (a grid of tiles) or Origami
(panels that fold in new covers) under Options.

## Install

Download `Covers-for-Steam-0.2.pkg` from
[Releases](https://github.com/gkaramanis/steam-screensaver/releases), open it
and follow the steps. To use the zip instead, unzip it and double-click
`Covers for Steam.saver`. Requires macOS 14 or later, Apple silicon or Intel.

Then choose **Covers for Steam** under System Settings → Wallpaper → Screen
Saver… → Custom (macOS 26 and later) or System Settings → Screen Saver
(macOS 14 and 15).

The saver needs Steam installed with a library you have opened at least once,
so the covers are in its cache.

## Building

```sh
./build.sh --install          # build and install into ~/Library/Screen Savers
./build.sh --release          # sign, notarize, staple and zip into build/
./build.sh --pkg              # the same, plus a signed, notarized installer
swift tools/thumbnail.swift   # redraw the System Settings thumbnails
```

## License

MIT. Not affiliated with Valve. Steam is a trademark of Valve Corporation.
