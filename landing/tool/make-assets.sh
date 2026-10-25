#!/bin/sh
# Makes the site's binary assets from sources elsewhere in the repository. Run it from anywhere after a source
# changes, then commit what it writes; `npm run build` never runs it.
#
#   sh landing/tool/make-assets.sh                                                  # icons and the link preview
#   sh landing/tool/make-assets.sh <Russian screenshots dir> <English screenshots dir>   # and the screenshots
#
# Screenshots: the app's 2x PNGs (780 px wide = a 390 pt phone) from the widget test that renders every screen,
# design/figma-plugin/render_screens_test.dart.txt (see design/figma-plugin/README.md). The Russian ones are its
# output as is; the English ones come from its English copy that tool/en-screens.py writes (it says how to run it).
#
# The fonts are not made here: src/fonts/arimo-latin.woff2 and arimo-cyrillic.woff2 are Google Fonts' own variable
# Arimo files (weights 400 to 700 in one file), kept as they are, with their licence OFL-arimo.txt.
#
# Needs ImageMagick, rsvg-convert and hb-view, and cwebp for the screenshots:
#   brew install imagemagick librsvg harfbuzz webp
set -eu
RU=
EN=
if [ $# -gt 0 ]; then
  RU=$(cd "${1:?Russian screenshots dir}" && pwd)
  EN=$(cd "${2:?English screenshots dir}" && pwd)
fi
cd "$(dirname "$0")/.."
FONTS=../mobile/assets/google_fonts
ICON=../mobile/tool/icon

# 1. Icons. public/favicon.svg is drawn by hand from the app icon (it says how). The home-screen icon for iPhone
#    is the app's iOS icon, without transparency like the App Store wants; favicon.ico serves old browsers.
#    rsvg-convert draws the SVGs (ImageMagick's own SVG reader can't follow icon.svg's link to foreground.svg).
rsvg-convert -w 180 -h 180 "$ICON/icon.svg" |
  magick - -background '#066849' -alpha remove -alpha off -strip public/apple-touch-icon.png
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
for size in 16 32 48; do rsvg-convert -w $size -h $size public/favicon.svg -o "$tmp/$size.png"; done
magick "$tmp/16.png" "$tmp/32.png" "$tmp/48.png" public/favicon.ico

# 2. Screenshots as WebP, 780 px (sharp phones) and 390 px wide. name:file of the renderer. Only when the
#    screenshot folders are given.
if [ -n "$RU" ]; then
  for pair in today:02_today_with_data health:04_pet_2_health passport:04_pet_3_passport visits:09_visits_list \
    supplies:11_supplies_list supply:11_supplies_detail; do
    name=${pair%%:*}
    file=${pair##*:}
    for lang in en ru; do
      if [ "$lang" = en ]; then dir=$EN; else dir=$RU; fi
      out=src/assets/screens/$lang
      mkdir -p "$out"
      cwebp -quiet -q 82 -m 6 -sharp_yuv -metadata none "$dir/$file.png" -o "$out/$name-780.webp"
      cwebp -quiet -q 82 -m 6 -sharp_yuv -metadata none -resize 390 0 "$dir/$file.png" -o "$out/$name-390.webp"
    done
  done
fi

# 3. The picture for link previews (Open Graph), 1200x630: the icon and the name on the palette's mint
#    (primary-soft), the same in both languages. hb-view (HarfBuzz) sets the name in Arimo Bold, the app's font, in
#    ink: this ImageMagick has no font support of its own.
rsvg-convert -w 168 -h 168 public/favicon.svg -o "$tmp/icon.png"
hb-view --font-file="$FONTS/Arimo-Bold.ttf" --font-size=112 --foreground=191E28 --background=00000000 \
  --margin=0 --output-format=png --output-file="$tmp/name.png" 'Collarbell'
magick "$tmp/icon.png" -size 44x1 xc:none \( "$tmp/name.png" -trim +repage \) -background none -gravity center \
  +append "$tmp/lockup.png"
magick -size 1200x630 xc:'#E6F8EC' "$tmp/lockup.png" -gravity center -composite -strip -depth 8 public/og-image.png

echo "Assets written."
