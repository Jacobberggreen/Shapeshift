#!/bin/bash
# Builds build/Shapeshift.app from the SwiftPM executable (ad-hoc signed).
set -euo pipefail
cd "$(dirname "$0")/.."

SCRATCH_ARGS=()
if [ -n "${SCRATCH_PATH:-}" ]; then
  SCRATCH_ARGS=(--scratch-path "$SCRATCH_PATH")
fi

swift build -c release ${SCRATCH_ARGS[@]+"${SCRATCH_ARGS[@]}"}
BIN="$(swift build -c release ${SCRATCH_ARGS[@]+"${SCRATCH_ARGS[@]}"} --show-bin-path)/Shapeshift"

APP="build/Shapeshift.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Shapeshift"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Shapeshift</string>
  <key>CFBundleDisplayName</key><string>Shapeshift</string>
  <key>CFBundleIdentifier</key><string>dev.shapeshift.app</string>
  <key>CFBundleExecutable</key><string>Shapeshift</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleIconName</key><string>AppIcon</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>NSHumanReadableCopyright</key><string>Copyright © 2026 Jacob Berggren. MIT License.</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSServices</key>
  <array>
    <dict>
      <key>NSMenuItem</key>
      <dict><key>default</key><string>Shapeshift…</string></dict>
      <key>NSMessage</key><string>openWithShapeshift</string>
      <key>NSPortName</key><string>Shapeshift</string>
      <key>NSRequiredContext</key><dict/>
      <key>NSSendFileTypes</key>
      <array><string>public.data</string></array>
    </dict>
  </array>
</dict>
</plist>
PLIST

[ -f Resources/MenuBarIcon.pdf ] && cp Resources/MenuBarIcon.pdf "$APP/Contents/Resources/"

# App icon: Resources/AppIcon.icon (made in Icon Composer) compiled to Assets.car + AppIcon.icns. actool needs an absolute path.
ICON="$PWD/Resources/AppIcon.icon"
if [ -d "$ICON" ]; then
  ICON_TMP="$(mktemp -d)"
  xcrun actool "$ICON" --compile "$ICON_TMP" --platform macosx --minimum-deployment-target 13.0 \
    --app-icon AppIcon --output-partial-info-plist "$ICON_TMP/partial.plist" >/dev/null
  cp "$ICON_TMP/Assets.car" "$ICON_TMP/AppIcon.icns" "$APP/Contents/Resources/"
  rm -rf "$ICON_TMP"
else
  echo "warning: Resources/AppIcon.icon not found, building without an app icon" >&2
fi

plutil -lint "$APP/Contents/Info.plist" >/dev/null
[ "$(plutil -extract NSServices.0.NSMessage raw "$APP/Contents/Info.plist")" = "openWithShapeshift" ] \
  || { echo "NSServices missing from Info.plist" >&2; exit 1; }
plutil -extract NSServices.0.NSRequiredContext xml1 -o - "$APP/Contents/Info.plist" >/dev/null 2>&1 \
  || { echo "NSServices.0.NSRequiredContext missing from Info.plist" >&2; exit 1; }
[ "$(plutil -extract NSServices.0.NSSendFileTypes.0 raw "$APP/Contents/Info.plist" 2>/dev/null)" = "public.data" ] \
  || { echo "NSSendFileTypes must be public.data" >&2; exit 1; }

# actool's own AppIcon.icns stops at 256 px (blurry when large): use the full 16-1024 px one made by scripts/make-icns.sh.
if [ -f Resources/AppIcon.icns ]; then
  cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
else
  echo "warning: Resources/AppIcon.icns missing (run scripts/make-icns.sh); keeping actool's low-resolution icns" >&2
fi

xattr -cr "$APP"
codesign --force --sign - "$APP"
echo "Built $APP"
