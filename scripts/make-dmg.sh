#!/bin/sh
# Builds build/Shapeshift.dmg: a disk image that opens with Shapeshift next to an Applications shortcut to drag it onto.
# Run scripts/build-app.sh first. The icon layout is set through Finder (AppleScript); if that is not allowed
# (Automation permission) the image still works, just with Finder's default icon placement.
set -e
cd "$(dirname "$0")/.."
APP="build/Shapeshift.app"
[ -d "$APP" ] || { echo "Run scripts/build-app.sh first" >&2; exit 1; }
VOL="Shapeshift"
OUT="build/Shapeshift.dmg"
# ".noindex" keeps Spotlight from listing the staged copy as another Shapeshift app.
WORK="$(mktemp -d "${TMPDIR:-/tmp}/shapeshift-dmg.XXXXXX")"
WORK="$WORK.noindex"; rm -rf "$WORK"; mkdir -p "$WORK/stage"
cp -R "$APP" "$WORK/stage/Shapeshift.app"
ln -s /Applications "$WORK/stage/Applications"
HAVE_BG=0
if [ -f Resources/dmg-background.png ]; then
  mkdir "$WORK/stage/.background"
  cp Resources/dmg-background.png "$WORK/stage/.background/background.png"   # 1080x600 at 144 dpi = a 540x300 pt window, sharp on Retina
  HAVE_BG=1
fi
rm -f "$OUT" "$WORK/rw.dmg"
hdiutil create -quiet -volname "$VOL" -srcfolder "$WORK/stage" -fs HFS+ -format UDRW -ov "$WORK/rw.dmg"
MOUNT="$(hdiutil attach -nobrowse -noverify -noautoopen "$WORK/rw.dmg" | grep -o '/Volumes/.*' | head -1)"
osascript >/dev/null 2>&1 <<OSA || echo "note: could not set the icon layout (Finder automation not allowed); using the default layout" >&2
tell application "Finder"
  tell disk "$VOL"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {200, 140, 740, 440}
    set opts to the icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 112
    if $HAVE_BG is 1 then set background picture of opts to file ".background:background.png"
    set position of item "Shapeshift.app" of container window to {140, 150}
    set position of item "Applications" of container window to {400, 150}
    close
    open
    update without registering applications
    delay 1
    close
  end tell
end tell
OSA
[ "$HAVE_BG" = 1 ] && chflags hidden "$MOUNT/.background" 2>/dev/null || true
sync
hdiutil detach -quiet "$MOUNT" || { sleep 2; hdiutil detach -quiet -force "$MOUNT"; }
# Mounting registers the staged app with Launch Services; drop that entry so it does not show up as a duplicate app.
LSR=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
"$LSR" -u "$MOUNT/Shapeshift.app" >/dev/null 2>&1 || true
"$LSR" -u "$MOUNT" >/dev/null 2>&1 || true
hdiutil convert -quiet "$WORK/rw.dmg" -format UDZO -imagekey zlib-level=9 -o "$OUT"
rm -rf "$WORK"
echo "Built $OUT"
