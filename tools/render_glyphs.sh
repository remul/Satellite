#!/bin/sh
# Renders the glyphs on the launcher's discs, tools/glyphs/*.svg, to Media/Glyph*.tga (64x64,
# white with a black outline, tinted in game). Uses headless Chrome (it draws the SVGs' strokes,
# which ImageMagick drops) and ImageMagick.
#
#     sh tools/render_glyphs.sh
set -e
cd "$(dirname "$0")/.."
temp=$(mktemp -d)
for svg in tools/glyphs/*.svg; do
    name=$(basename "$svg" .svg)
    printf '<html><body style="margin:0;background:transparent">%s</body></html>' \
        "$(sed 's/width="64" height="64"/width="256" height="256"/' "$svg")" > "$temp/$name.html"
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu \
        --hide-scrollbars --window-size=256,256 --default-background-color=00000000 \
        --screenshot="$temp/$name.png" "file://$temp/$name.html" 2>/dev/null
    magick "$temp/$name.png" -background none -resize 64x64 -define tga:image-origin=TopLeft \
        -type TrueColorAlpha "Media/Glyph$name.tga"
    echo "Wrote Media/Glyph$name.tga"
done
rm -r "$temp"
