# Shapeshift — pie wheel with outcome preview, and a tabbed Settings window

Date: 2026-10-20
Status: Implemented (branch pie-wheel-and-settings)
Parent spec: `2026-10-20-polish-glass-and-wheel-design.md`. Where they differ, this one wins (the wheel's shape, its centre, and the Settings window).
Builds on: branch `polish-glass-and-wheel` (unmerged). Work happens on `pie-wheel-and-settings`.
Origin: owner feedback after hands-on testing of the glass wheel (round buttons look "a bit wrong"; wants a ring of pie slices like the reference screenshot; wants the centre to show the outcome; Settings is too long and cannot be resized).

## Summary

1. **Pie wheel.** The wheel is a ring made of sectors (pie slices), one per action. Slices do not touch: a constant gap runs between them and every slice has softly rounded corners. Slices are glass; the highlighted one takes the accent colour. The old round buttons are removed (Classic grid stays as it is).
2. **Outcome in the centre.** A capsule in the middle shows the current file as `FORMAT · size` (for example `PDF · 1.1 MB`). While a conversion slice is hovered, targeted by a dragged file, or selected with the keyboard, it shows the outcome instead: `PNG · ~340 KB`. Tool slices show the tool name. The dragged file icon sits over the capsule as in the reference.
3. **Settings window.** A normal resizable window with four tabs, nothing longer than its tab, and the default quality stated.

## Decisions taken with the owner

- Default quality is 85 % (`SettingsStore.quality`), used for lossy output (JPEG, HEIC, WebP, compressed audio and video). Settings states this and offers "Reset to 85 %".
- Centre content: current format and size by default; the new format and an estimated size on hover/target/selection.
- Estimated size exists for **images** (encode a small preview and extrapolate, as the editor does). For audio, video and anything else the capsule shows the target format name and the source size only (no estimate) — estimates for those need bitrate/duration analysis and are out of scope.
- Reference for the look: the owner's screenshot (four slices DOCX/JPG/PNG/TXT around a capsule showing a size; the dragged file icon overlapping the capsule). No public description of Tangerine's centre could be found, so the screenshot is the reference.

## 1. Pie wheel

### Geometry (pure, unit-tested)
- `WheelSector`: `innerRadius`, `outerRadius`, `startAngle`, `endAngle` (radians; 0 = top, clockwise). Angles are the *unspaced* boundaries between neighbours; the gap is applied when drawing. `centroid` = point at mid-radius and mid-angle (the navigator keeps working on centroids).
- `WheelItem` = `id`, `entry`, `sector`; `offset` is the centroid.
- Constants: gap 6 pt (constant width, parallel edges — not a constant angle), corner radius 9 pt, first ring starts at inner radius 78, ring thickness 64 (tools ring in Two rings: 56), minimum slice width at mid-radius 54 pt, panel margin 16.
- A ring of `n` slices is pushed outwards until each slice is at least 54 pt wide at mid-radius (`midRadius ≥ n · (54 + 6) / sweep`).
- **Two rings:** tools in an inner ring, formats in an outer ring that starts 6 pt beyond the inner ring's outer edge; both start with the first slice centred at the top and run clockwise.
- **Split ring:** one ring; the formats group is centred at the top, then one empty slot, then the tools, then one empty slot (single kind: a plain ring).
- **Two steps:** root = two half-ring slices ("Convert" left, "Tools" right); category step = one ring of that kind. Only the Finder popup shows the root (drags show one kind).
- **Classic grid:** unchanged, no wheel items.
- Panel size = `2 · (outermost radius + 16)`, square, covering every step of the style.

### Drawing
- `SectorShape(sector:, gap:, cornerRadius:)`: an annular sector with parallel straight side edges `gap/2` away from the true radial boundary, rounded corners, built as a sampled polyline path (no arc-direction pitfalls). Corner circle centres: outer corners at distance `ro − rc`, inner corners at `ri + rc` from the centre, offset `gap/2 + rc` from the radial boundary (angle `± asin((gap/2 + rc)/d)`).
- Each slice is a `GlassSurface` in that shape (interactive), content (format name, or SF Symbol for a tool) placed at the centroid, `contentShape` = the shape so hover, click and file-drop use the slice area exactly.
- Highlight (hover, drag-target, keyboard) = accent fill under the glass, white text. Short scale-and-fade appearance as before.

### Centre capsule
- Glass capsule, about 120 × 52, two lines: title (format or tool name) and detail (size). Never hit-testable.
- `WheelOutcomeSource`: `sourceFormat: FileFormat?` (nil when files differ), `sourceBytes: Int?` (sum of the files), `estimate: ((FileFormat) async -> Int?)?`.
- Default (nothing highlighted): `"<source format> · <size>"`; with several files the subtitle also says "N files". Formats mixed → title "Shapeshift".
- Highlighted conversion slice: title = target format; detail = `~<estimated size>` once known (`…` while computing), or the source size when no estimate exists. Highlighted tool slice: tool name, detail "Edit". Category: category name.
- Estimates are computed lazily on first highlight of a format, cached per wheel, and never block interaction. Images only (target must be writable by `ImageWriter`; WebP target → no estimate). With several files the estimate of the first file is scaled by `totalSourceBytes / firstFileBytes` and marked `~`.
- Sizes formatted with `ByteCountFormatter` (file style).

## 2. Settings window

- `NSWindow` titled, closable, miniaturizable, **resizable**; initial 560 × 460, minimum 520 × 380 (plus the title-bar inset); same glass window helper as before.
- Tabs (`TabView`, each a grouped `Form` with the glass-friendly background):
  - **General:** trigger keys (Convert, Tools) with the validity message; Quality slider with caption "Used for lossy output — JPEG, HEIC, WebP, compressed audio and video. Default 85 %." and a "Reset to 85 %" button.
  - **Appearance:** Menu style picker; Transparent image preview picker.
  - **Finder & keys:** the Finder section (refresh services, keyboard-shortcuts button, explanation) and the Input Monitoring status/button.
  - **Tools:** ffmpeg status.
- `SettingsStore.defaultQuality` (0.85) is the single source of the default.

## Testing

- Unit: `WheelLayout` (slice counts, widths ≥ 54 pt, no overlap within and between rings, first slice centred at the top and clockwise, group gap in Split ring, root halves, panel size covers every step, classic = none), `SectorShape` (contains the centroid, excludes a point in the gap, excludes the sharp corner point, bounded by the outer radius), `WheelNavigator` + reachability over the new geometry, `WheelModel` (hub title/detail by selection, estimate requested once and cached, failing/unavailable estimate, multi-file text), `OutcomeEstimator` (image → positive estimate, audio/video → nil, source size sum), `SettingsStore.defaultQuality`.
- Manual: pie look (gaps, rounded corners, glass, accent highlight), the centre capsule during a real drag (default text, hover preview, dragged icon over it), sector hover/drop/keyboard in every style, Settings tabs and resizing, quality default text and reset.

## Non-goals

- Estimates for audio, video, PDF and archives; per-format icons; animation beyond the existing appearance transition; a Settings preview of wheel styles.

## Open questions

- Whether the glass sectors look right in the non-activating drag panels can only be judged by hand (same risk as before; the fallback is the material look).
