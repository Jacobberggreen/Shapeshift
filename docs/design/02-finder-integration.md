# Shapeshift Stage 3a — Finder right-click

Date: 2026-10-20
Status: Draft, awaiting review
Parent spec: `2026-10-19-shapeshift-design.md` (Stage 3, "Finder right-click integration"). Where they differ, this one wins for 3a.
Builds on: stage 2 (branch `stage-2-frame-and-tools`, not yet merged). Work happens on `stage-3a-finder-integration`.

Stage 3 is split into 3a Finder, 3d PDF tools, 3c archives, 3e text/subtitles. Video tools (3b) are dropped: converting video to audio and between video formats already works from stage 1.

## Summary

Right-click one or more files in Finder → **Shapeshift…** (at the bottom of the right-click menu, inline or under Services). A popup opens at the mouse with the same tiles as Shift-drag, in two rows: **Convert to** (formats) and **Tools** (Frame, Crop, Compress, Strip metadata; shown only when every file is an image). Click a tile, or use arrows + Return, Esc to close. The choice goes through the same job paths as Shift-drag.

## Mechanism: macOS Services (decision)

The app declares a Service (`NSServices` in `Info.plist`) that accepts files (`NSSendFileTypes: public.data`) and is handled by `NSApp.servicesProvider`. Finder lists it at the bottom of the right-click menu, inline or under a Services submenu (app-declared Services do not appear under Quick Actions).

Why not an Automator Quick Action installed into `~/Library/Services`: it needs a hand-built `.workflow` bundle, an install/uninstall step and a URL scheme just to call back into the app. A declared Service needs none of that, works as soon as the app has been launched once from where it lives, and cannot be left behind after deleting the app. Why not a Finder Sync extension: needs a separate signed extension target; too heavy for an ad-hoc-signed personal app.

Consequences: no install button. If the entry is missing, Settings explains where to enable it (System Settings › Keyboard › Keyboard Shortcuts › Services › Files and Folders › Shapeshift) with a button that opens that pane, and a "Refresh services" button that runs `NSUpdateDynamicServices()`.

## Architecture

1. **`ServiceProvider`** (new, `ShapeshiftApp`): `@objc func openWithShapeshift(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString>)`. Reads file URLs from the pasteboard (`readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])`), drops non-existent paths and directories, and hands the list to `AppController.showFinderPicker(urls:)` on the main actor. An empty list sets `error` and does nothing.
2. **`ActionPickerModel`** (new): holds `formats: [FileFormat]` and `tools: [EditTool]` (empty when the files are not all images) plus one selection index spanning both rows. Arrow movement: left/right moves through the combined order rather than within a row, up/down between rows keeping the column where possible. Pure and unit-tested. Existing `PickerModel`/`ToolPickerModel` are not changed.
3. **`ActionPickerView`** (new, SwiftUI): the two rows, title "Shapeshift — N file(s)". Tiles reuse the look of the existing tiles (shared tile views extracted if that stays small; otherwise visual duplication is accepted, not logic duplication). Tiles are buttons (click), not drop targets.
4. **`KeyPanel`** (new, `NSPanel` subclass): like `FormatPanel` but `canBecomeKey == true`, shown as a non-activating key panel (no `NSApp.activate`, so Finder stays frontmost), closes on resign-key and on Esc. Keyboard handling uses a **local** key monitor, so Finder-opened popups need no Input Monitoring permission. Position: at the mouse location, clamped to the screen's visible frame (same math as `FormatPanel.present`).
5. **`AppController`**: `showFinderPicker(urls:)` builds the model (using `service.commonTargets(for:)`), shows the `KeyPanel`, and on choice calls the existing `startConversion(urls:format:)` or `openEditor(urls:tool:)`. If `commonTargets` is empty *and* there are no tools, show a notification "Shapeshift can't convert these files" instead of an empty popup. Opening a new Finder popup replaces any previous one. The Shift-drag panels and logic are untouched.
6. **`AppMain`/`AppDelegate`**: sets `NSApp.servicesProvider` and calls `NSUpdateDynamicServices()` once at launch.
7. **`scripts/build-app.sh`**: adds `NSServices` to `Info.plist`:
   - `NSMenuItem.default` = "Shapeshift…"
   - `NSMessage` = `openWithShapeshift`
   - `NSPortName` = `Shapeshift`
   - `NSSendFileTypes` = [`public.data`]
   - `NSRequiredContext` = empty dictionary (required for the entry to show by default)
8. **Settings**: new section "Finder": status text, "Open Keyboard Shortcuts…", "Refresh services".

## Data flow

Right-click → Shapeshift… → macOS launches/messages the app → `ServiceProvider` → `AppController.showFinderPicker` → `KeyPanel` → tile → `startConversion` or `openEditor` (unchanged paths) → sibling output + notification.

## Error handling

- Missing files / folders in the selection are skipped; nothing usable → no popup, error returned to the Service machinery.
- No ffmpeg and a video/audio selection: same behaviour as Shift-drag (`commonTargets` reflects availability).
- Popup shown while a Shift-drag panel is visible: the drag panel is hidden first.
- Mixed kinds (image + audio): formats are the common targets; tools row hidden.

## Testing

- `ActionPickerModel`: selection movement across rows/edges, empty tools row, single row, wrapping rules; `selectedAction` for both kinds.
- `ServiceProvider` URL extraction (pure function over an `NSPasteboard(name: .init("test"))`): files kept, missing paths and directories dropped, empty result.
- `Info.plist` check (script-level): build-app produces a plist where `plutil -extract NSServices` succeeds and contains the message name (run in the manual checklist, plus a small shell test).
- Manual checklist (added to `docs/manual-test-checklist.md`): entry visible in Finder after first launch; popup position; click / arrows / Return / Esc; image selection shows tools; audio selection shows only formats; multi-file; works with the app not running; works without Input Monitoring.

## Non-goals

- Per-format menu entries ("Convert to PNG") — can be added later.
- Folder selection / recursive conversion.
- Drag-free use of PDF tools (arrive in 3d and plug into the Tools row).
- Audio→video ("wav to mp4"): stage 1 does not offer it; unchanged here.

## Open questions

- Whether macOS shows an app-provided Service from an `LSUIElement` ad-hoc-signed app in Finder's right-click menu without extra steps cannot be tested here; the manual checklist covers it, and the fallback is the Services submenu.
