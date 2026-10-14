#!/bin/bash
# Copy Steam library art from the local cache into one flat folder for the
# macOS slideshow screensaver.
#
# Usage: sync-steam-art.sh [dest]
#   KIND=cover (default) uses library_600x900.jpg; KIND=hero uses library_hero.jpg.
#   HIRES=1 replaces 300x450 covers with the larger _2x cover from Steam's CDN
#   (600x900 in practice; some apps return 404 and keep the cached copy).

set -euo pipefail

SRC="$HOME/Library/Application Support/Steam/appcache/librarycache"
DEST="${1:-$HOME/Pictures/Steam Art}"
KIND="${KIND:-cover}"
HIRES="${HIRES:-0}"
CDN="https://shared.steamstatic.com/store_item_assets/steam/apps"

case "$KIND" in
  cover) name="library_600x900.jpg" ;;
  hero)  name="library_hero.jpg" ;;
  *) echo "KIND must be cover or hero" >&2; exit 1 ;;
esac

[ -d "$SRC" ] || { echo "No Steam cache at $SRC" >&2; exit 1; }
mkdir -p "$DEST"

width() { sips -g pixelWidth "$1" 2>/dev/null | awk '/pixelWidth/ {print $2}'; }

copied=0 upgraded=0 total=0
for dir in "$SRC"/*/; do
  app=$(basename "$dir")
  case "$app" in *[!0-9]*) continue ;; esac

  # Newer Steam builds put some images one level down in hashed folders.
  # Take the largest file of that name.
  best=$(find "$dir" -type f -name "$name" -exec stat -f '%z %N' {} + 2>/dev/null \
    | sort -rn | head -1 | cut -d' ' -f2-)
  [ -n "$best" ] || continue
  total=$((total + 1))

  out="$DEST/${app}_${KIND}.jpg"

  # Keep a CDN upgrade once fetched, since the cache copy is smaller.
  if [ -f "$out" ] && [ "$(width "$out")" -gt "$(width "$best")" ]; then
    continue
  fi

  if [ "$KIND" = cover ] && [ "$HIRES" = 1 ] && [ "$(width "$best")" -lt 600 ]; then
    tmp="$DEST/.${app}.part"
    if curl -fs --max-time 20 -o "$tmp" "$CDN/$app/library_600x900_2x.jpg"; then
      mv "$tmp" "$out"
      upgraded=$((upgraded + 1))
      continue
    fi
    rm -f "$tmp"
  fi

  if ! cmp -s "$best" "$out"; then
    cp "$best" "$out"
    copied=$((copied + 1))
  fi
done

echo "$(date '+%F %T') $total apps with $KIND art; $copied copied, $upgraded upgraded from CDN -> $DEST"
