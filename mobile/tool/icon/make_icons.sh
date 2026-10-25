#!/bin/sh
# Renders the app icon from the drawings next to this script into every size Android and iOS want.
# Run it after changing a drawing, then commit the PNGs it writes:
#   sh mobile/tool/icon/make_icons.sh
# Needs rsvg-convert and magick: brew install librsvg imagemagick
set -eu
cd "$(dirname "$0")"
RES=../../android/app/src/main/res
IOS=../../ios/Runner/Assets.xcassets/AppIcon.appiconset

# Android 8+: an adaptive icon of two layers (108dp) and a one-colour layer for themed icons (Android 13+);
# the background is the colour ic_launcher_background. Older Android: a round 48dp icon.
for density in mdpi:1 hdpi:1.5 xhdpi:2 xxhdpi:3 xxxhdpi:4; do
  name=${density%%:*}
  scale=${density##*:}
  layer=$(echo "108 * $scale / 1" | bc)
  legacy=$(echo "48 * $scale / 1" | bc)
  mkdir -p "$RES/mipmap-$name"
  rsvg-convert -w "$layer" -h "$layer" foreground.svg -o "$RES/mipmap-$name/ic_launcher_foreground.png"
  rsvg-convert -w "$layer" -h "$layer" monochrome.svg -o "$RES/mipmap-$name/ic_launcher_monochrome.png"
  rsvg-convert -w "$legacy" -h "$legacy" legacy.svg -o "$RES/mipmap-$name/ic_launcher.png"
done

# iOS: the whole square for each file the asset catalog lists (Icon-App-60x60@3x.png is 180 px). The App Store
# refuses icons with an alpha channel, so it is removed.
for file in "$IOS"/Icon-App-*.png; do
  base=$(basename "$file" .png)
  points=$(echo "$base" | sed 's/^Icon-App-\([0-9.]*\)x.*/\1/')
  factor=$(echo "$base" | sed 's/.*@\([0-9]\)x$/\1/')
  pixels=$(echo "$points * $factor / 1" | bc)
  rsvg-convert -w "$pixels" -h "$pixels" icon.svg | magick - -background '#066849' -alpha remove -alpha off "$file"
done
echo "Icons written."
