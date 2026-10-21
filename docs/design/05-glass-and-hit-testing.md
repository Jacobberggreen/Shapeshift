# Shapeshift — combined wheel for drags, reliable slice hit-testing, Liquid Glass look

Date: 2026-10-20
Status: Implemented (branch glass-and-hit-testing)
Parent spec: `2026-10-20-pie-wheel-and-settings-design.md`. Where they differ, this one wins.
Builds on: branch `pie-wheel-and-settings` (unmerged). Work happens on `glass-and-hit-testing`.
Origin: owner feedback after testing the pie wheel: (1) with "Two rings" only one ring is visible during a drag and Shift+Option stops being useful; (2) the slice under the pointer/file is not highlighted reliably ("feels slanted"); (3) all surfaces look like frosted glass, with no Liquid Glass effect.

## 1. One wheel for both triggers (Two rings and Split ring)

- `WheelContentPlanner.plan(style:intent:formats:allImages:) -> WheelContent?` decides what a drag shows:
  - **Two rings, Split ring:** Shift and Shift+Option show the same combined wheel: all common target formats plus, when every file is an image, all edit tools. Non-image files get formats only. (Option is not needed to reach tools.)
  - **Two steps:** Shift → formats only; Shift+Option → tools only (images only; otherwise nothing). Unchanged from before.
  - **Classic grid:** unchanged and not planned here.
  - Nothing to show (no formats and no tools) → nil.
- `AppController.showPicker` uses the planner for the three wheel styles. For the combined styles both intents take the same path and the same panel, so pressing or releasing Option mid-drag does not rebuild the wheel (the existing re-show guard applies). The Finder popup is unchanged (always combined).
- Settings › Appearance shows a one-line description under the Menu style picker (`MenuStyle.summary`), explaining, for example, that Two steps first asks Convert or Tools in Finder and that drags show one kind per trigger.

## 2. Hit-testing in one place

- Pure `WheelLayout.item(at:in:) -> Int?`: maps a point relative to the wheel centre (y down) to the index of the slice containing it. A point belongs to a slice when its radius is within `[innerRadius − gap/2, outerRadius + gap/2]` and its angle (0 = top, clockwise) lies within the slice's angular range (ranges may start negative and cross the top). The visible gaps between slices belong to the nearest slice (no dead zones inside a ring); the hub area and everything outside the rings return nil.
- `WheelPickerView` no longer relies on per-slice SwiftUI hit regions. Slices are drawn only (non-interactive glass, accent fill when lit, labels). One full-panel interaction layer on top handles:
  - **hover:** `onContinuousHover` → `model.selected = item(at:)` (nil clears);
  - **click:** `SpatialTapGesture` → activate the slice under the click;
  - **file drops:** `onDrop(of: [.fileURL], delegate:)` with a `DropDelegate` whose `dropEntered`/`dropUpdated` set `model.selected` from `info.location` and return a `.copy` proposal, `dropExited` clears it, `performDrop` activates the slice under the drop (false when none);
  - the 0.4 s category dwell during a drag stays (start when the targeted slice is a category, cancel when it changes).
- Accessibility: each slice is an accessibility element with its label, the button trait and an activation action; the interaction layer is hidden from accessibility.
- The press-bounce of interactive glass is dropped on slices (they are dragged onto, not clicked).

## 3. Liquid Glass look

- Likely causes of the "just frosted" look: the editor and Settings put a behind-window `NSVisualEffectView` under the glass (glass over an already blurred layer reads as plain frost); there is nothing colourful behind the glass for it to refract; only the standard glass variant is used.
- **Glass style setting** (Settings › Appearance): `GlassStyle` = Liquid Glass (default, `.regular`), Clear glass (`.clear`), Frosted (material). Stored under `glassStyle` (unknown → liquid). `GlassSurface` reads it live (`@AppStorage("glassStyle")`); on macOS < 26 the frosted material is always used.
- **macOS 26+ windows:** `GlassWindow.install` no longer inserts the behind-window blur; the hosting view is the content view. A soft `GlassBackdrop` (window background colour plus an accent/purple/teal gradient with two blurred colour blobs, light/dark aware) sits behind the root view so the glass cards have something to bend. macOS < 26 keeps the current blur view and no backdrop.
- If it still looks frosted after this, the owner sends screenshots (the wheel and the editor) and the next step is `NSGlassEffectView`-based hosting for the panels.

## Testing

- Unit: `WheelContentPlanner` (all style/intent/kind combinations, nil cases), `WheelLayout.item(at:in:)` (centroids map to their own slice for every style/step, boundary points, ring gap, hub/outside nil, angle wrap at the top, twoSteps root halves with negative angles), `MenuStyle.summary` non-empty, `SettingsStore.glassStyle` default/round trip/fallback.
- Manual: Two rings and Split ring show the combined wheel for both triggers; Two steps and Classic grid unchanged; the slice under the pointer/file is the one lit, including near gaps and ring borders; drops land on the lit slice; glass looks like glass in the editor, Settings and wheel, compare the three Glass styles.

## Non-goals

- Reworking the wheel geometry, an `NSGlassEffectView` rewrite (only if screenshots show the SwiftUI glass is not enough), and any per-slice press effects.
