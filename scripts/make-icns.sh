#!/bin/sh
# Regenerates Resources/AppIcon.icns (16-1024 px) from Resources/AppIcon.icon. Run it after changing the icon in Icon Composer,
# then commit the result. actool's own .icns stops at 256 px (blurry when large), so the full set is rendered from Assets.car.
# Needs a built build/Shapeshift.app (run scripts/build-app.sh first). The work happens in a ".noindex" folder so Spotlight
# never lists the temporary copy as another Shapeshift app.
set -e
cd "$(dirname "$0")/.."
[ -d build/Shapeshift.app ] || { echo "Run scripts/build-app.sh first" >&2; exit 1; }
WORK="$(mktemp -d "${TMPDIR:-/tmp}/shapeshift-icon.XXXXXX")"
WORK="$WORK.noindex"; rm -rf "$WORK"; mkdir -p "$WORK"
cp -R build/Shapeshift.app "$WORK/Shapeshift.app"
swift scripts/render-icon.swift "$WORK/Shapeshift.app" "$WORK/icon1024.png"
[ -s "$WORK/icon1024.png" ] || { echo "Rendering the icon failed" >&2; exit 1; }
SET="$WORK/AppIcon.iconset"; mkdir "$SET"
for size in 16 32 128 256 512; do
  sips -z $size $size "$WORK/icon1024.png" --out "$SET/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) "$WORK/icon1024.png" --out "$SET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$SET" -o Resources/AppIcon.icns
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$WORK/Shapeshift.app" >/dev/null 2>&1 || true
rm -rf "$WORK"
echo "Wrote Resources/AppIcon.icns"
