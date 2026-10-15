#!/bin/sh
# Renders Satellite's logo, tools/logos/*.svg, to 256x256 textures (white with a black outline,
# tinted in game): Satellite.svg to Media/SatelliteLogo.tga and SatelliteButtons.svg to
# Media/SatelliteLogoButtons.tga. Uses headless Chrome (it draws the SVGs' strokes, which
# ImageMagick drops) and ImageMagick.
#
#     sh tools/render_logos.sh
set -e
cd "$(dirname "$0")/.."
temp=$(mktemp -d)
render() {
    printf '<html><body style="margin:0;background:transparent">%s</body></html>' \
        "$(sed 's/width="256" height="256" viewBox/width="1024" height="1024" viewBox/' "tools/logos/$1.svg")" > "$temp/$1.html"
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu \
        --hide-scrollbars --window-size=1024,1024 --default-background-color=00000000 \
        --screenshot="$temp/$1.png" "file://$temp/$1.html" 2>/dev/null
    magick "$temp/$1.png" -background none -resize 256x256 -define tga:image-origin=TopLeft \
        -type TrueColorAlpha "Media/$2.tga"
    echo "Wrote Media/$2.tga"
}
render Satellite SatelliteLogo
render SatelliteButtons SatelliteLogoButtons
rm -r "$temp"
