# steam-screensaver

Show the art from your Steam library as the Mac screensaver. There are two
routes. One is a native `.saver` that reads Steam's cache directly. The other is
a sync script feeding macOS's built-in slideshow screensaver.

## Screensaver (v0.1)

`saver/` holds a native `.saver`, "Covers for Steam". It reads the covers
straight from Steam's cache and shows them as a wall of tiles, one fading to
another game every 3 s. `./build.sh` builds a universal, ad-hoc signed bundle
into `build/`, and `./build.sh --install` copies it to `~/Library/Screen Savers`.
It logs to the `local.covers-for-steam` subsystem:

```sh
log show --last 10m --predicate 'subsystem == "local.covers-for-steam"'
```

## Slideshow route

The files below feed the built-in slideshow screensaver instead.

- `sync-steam-art.sh [dest]` copies `library_600x900.jpg` per app ID into
  `dest` (default `~/Pictures/Steam Art`) as `<appid>_cover.jpg`.
  `KIND=hero` copies the wide `library_hero.jpg` instead.
  `HIRES=1` swaps 300×450 covers for the CDN's `_2x` cover (no API key).
- `local.steam-screensaver.plist` is the launchd agent (not installed).

## Set up

```sh
HIRES=1 ./sync-steam-art.sh
cp local.steam-screensaver.plist ~/Library/LaunchAgents/
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/local.steam-screensaver.plist
```

Then System Settings → Screen Saver → a slideshow style (Shifting Tiles,
Vintage Prints …) → Source → Choose Folder → `~/Pictures/Steam Art`.

## Limits

- The cache only holds games Steam has shown in the library view.
- Six cached apps have no `_2x` cover on the CDN and stay at 300×450.
- Full-library coverage needs the owned app IDs from the Steam Web API
  (`IPlayerService/GetOwnedGames`, needs a key). Downloading the art for
  those IDs needs no key.
