# Shapeshift polish — window-frame border, Liquid Glass design, wheel menus

Date: 2026-10-20
Status: Implemented (branch polish-glass-and-wheel)
Parent specs: stage 2 (Frame and image tools) and stage 3a (Finder right-click). Where they differ, this one wins.
Builds on: branch `stage-3a-finder-integration` (unmerged). Work happens on `polish-glass-and-wheel`.
Origin: the owner's first hands-on test of 3a (window-frame border can still be given a thickness; checkerboard behind PNG previews; the picker is "just a box").

## Summary

1. **Bug:** with "Window frame" on, border thickness/colour no longer apply or show; a real macOS window has one fixed hairline border.
2. **Glass design:** every Shapeshift surface (editor, Settings, pickers) uses one shared glass component — real Liquid Glass on macOS 26+, frosted material before that. Rounded corners everywhere.
3. **Transparent PNGs:** the editor preview sits on a frosted surface instead of a checkerboard, so transparency reads as glass. The checkerboard stays available as a Settings option, off by default.
4. **Wheel menus:** the picker becomes round glass buttons arranged around the mouse pointer, in four selectable styles (Settings): Two rings (default), Split ring, Two steps, Classic grid (today's box).

## Goals / non-goals

Goals: the four items above; the same code path for Shift-drag and Finder pickers; no change to conversion/edit behaviour or exported pixels (except the window-frame border, item 1).
Non-goals: animations beyond a short appear/hover transition; custom icons per format; theming beyond system light/dark; changing what formats/tools are offered; a live preview of wheel styles inside Settings.

## 1. Window-frame border (EditCore + editor UI)

- `FrameStep`: when `style.windowChrome` is true, `borderWidth`/`borderColor` are ignored. A fixed hairline is drawn instead along the window outline: width `1 * unit`, colour black at 18 % alpha for the light theme, white at 22 % alpha for the dark theme. Drawn inside the card clip like today's border, so the shape is preserved.
- `FrameStyle` and stored presets are unchanged (the values stay in the model; they are simply not used while the window frame is on). Decoding is unaffected.
- `EditorView`: "Border width" and "Border colour" are hidden while "Window frame" is on.
- Tests (EditCore): with chrome on, changing `borderWidth`/`borderColor` does not change the rendered image; the card edge pixel differs from the same render without the hairline; light/dark hairline colours; non-chrome border behaviour unchanged.

## 2. Glass design system (ShapeshiftApp)

- New `GlassSurface`: a `View` modifier `glassSurface(cornerRadius:interactive:)` and `glassSurface(in:interactive:)`. On macOS 26+ it applies `glassEffect(.regular…, in: RoundedRectangle(cornerRadius:))` (interactive variant for buttons); earlier it uses `.regularMaterial` in the same shape with a hairline stroke. A `GlassGroup` container wraps `GlassEffectContainer` on macOS 26+ and is a plain `Group` earlier. Deployment target stays macOS 13.
- All glass lives behind this component so styling changes in one place.
- **Editor window** (`ImageEditorController`, `EditorView`): `titlebarAppearsTransparent`, `.fullSizeContentView`, window background is a behind-window `NSVisualEffectView`; sidebar becomes a rounded glass card with padding; preview area is a rounded glass field; bottom bar floats as a glass rounded rectangle (radius 18). Controls keep system styles. Minimum size stays 760×520.
- **Settings window** uses the window blur with grouped form sections (no separate glass cards); the small **notification-free panels** get the same surface and rounded corners.
- **Transparency preview setting:** `SettingsStore.transparencyPreview: TransparencyPreview` (`frosted` default, `checkerboard`), key `transparencyPreview`, unknown/missing → `frosted`. Frosted = the preview field's own glass shows through transparent pixels (no extra pattern); checkerboard = today's `Checkerboard` drawn behind the image. Exported files are unaffected.
- Tests: `SettingsStore` round-trip and fallback for the new key. Visual results go in the manual checklist.

## 3. Wheel menus

### Model and layout (pure, unit-tested)
- `WheelItem`: `id`, `PickerAction`, `ring` (inner/outer or arc), `offset: CGPoint` from the wheel centre, `diameter`.
- `MenuStyle` (Settings key `menuStyle`; missing/unknown → `twoRings`): `twoRings`, `splitRing`, `twoSteps`, `classicGrid`.
- `WheelLayout.items(for style:, formats:, tools:) -> [WheelItem]` and `WheelLayout.panelSize(...)`:
  - **twoRings:** tools on the inner ring (radius 70, button 52), formats on the outer ring (radius `max(125, fit)`, button 44). `fit` = the radius at which neighbouring buttons keep a 6 pt gap, so many formats never overlap. Items start at the top and run clockwise. Without tools only the outer ring exists (inner space stays empty so the dragged file never sits on a button).
  - **splitRing:** one ring with the formats centred at the top, an empty slot, then the tools, then an empty slot (a single kind gets a plain ring).
  - **twoSteps:** step 1 shows two category buttons ("Convert", "Tools"; only "Convert" when no tools — then the step is skipped); step 2 shows that category's items on one ring. The model tracks `step`.
  - Note: the Two-steps category buttons only appear in the Finder popup (drags show one kind each), so the hover-dwell only matters if a combined wheel is ever shown during a drag.
  - **classicGrid:** today's `ActionPickerView`/`FormatPickerView` boxes (restyled with `GlassSurface`), unchanged behaviour.
- Navigation: `WheelNavigator.next(from: index?, direction: PickerMove, items:) -> Int?` picks the item whose direction from the current one has the smallest angle to the arrow's vector (positive dot product only); with no selection the first arrow selects the item nearest the top. Return/Esc semantics are those of `ActionPickerModel.handle`; in twoSteps, Esc at step 2 returns to step 1, at step 1 closes.
- Panel size is derived from the layout (outermost offset + radius + 16 pt margin); it is clamped to the screen by shifting the wheel centre, not by shrinking it.

### Views and panels
- `WheelPickerView(model:, onChoose:)`: transparent background; each item is a `GlassSurface` circle (interactive) with the format's `displayName` or tool symbol/title, a hover/selected highlight, a short scale-and-fade appear transition. The hub in the centre shows the highlighted item's name and the file count (e.g. "PNG — 3 files") in a small glass disc. Items are both `Button`s (click) and drop targets (Shift-drag path), as the current tiles are.
- `FormatPanel.present(content:centeredAt:)` (new overload): sizes the panel to the content and centres it on the mouse (clamped). Both the drag panels and `KeyPanel` use it for the wheel styles; classicGrid keeps `present(content:at:)`.
- `AppController`: Shift-drag convert and tools intents use the wheel when `menuStyle != classicGrid`, with the same behaviour as today (tools wheel = tools only; convert wheel = formats only; the combined wheel appears only for the Finder entry). The Finder popup shows the combined wheel. In twoSteps with a drag in progress, hovering a category for 0.4 s opens its ring; drops land on items.
- Settings: "Menu style" picker (four options) and "Transparent image preview" picker (Frosted / Checkerboard).

### Risks
- Transparent areas of the large borderless panel might swallow mouse events instead of passing them through; the wheel is dismissed on any click outside an item, which is acceptable. To be checked by hand.
- Glass effects inside non-activating panels may render in their inactive look. If so, the fallback is the material look inside those panels.
- Animations/feel can only be judged by hand.

## Testing

- Unit tests: `WheelLayout` (no overlaps at 4/8/14 formats, start at top and clockwise, ring radii, bounds equal panel size, no-tools layouts, splitRing grouping and gap), `WheelNavigator` (direction choice, first selection, edges, single item), twoSteps state machine (step transitions, Esc), `SettingsStore` keys (`menuStyle`, `transparencyPreview`), FrameStep hairline tests.
- Manual checklist additions: glass look in the editor/Settings/pickers on macOS 26; frosted PNG preview and the checkerboard setting; all four menu styles from Shift-drag and from Finder; wheel near screen edges and on a second display; click outside; keyboard in every style; border controls hidden with the window frame.

## Open questions

- Whether `glassEffect` renders correctly inside the non-activating panels cannot be known without running it; the fallback above covers the failure mode.
