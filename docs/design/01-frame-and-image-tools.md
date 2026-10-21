# Shapeshift Stage 2 — Frame and image tools

Date: 2026-10-19
Status: Draft, awaiting review
Parent spec: `2026-10-19-shapeshift-design.md` (Stage 2 section). This document refines it; where they differ, this one wins for stage 2.
Builds on: stage 1 (branch `stage-1-core-conversion`, not yet merged). Work happens on `stage-2-frame-and-tools`, branched from it.

## Summary

Shift+Option-drag of an image opens a small tool menu (Frame, Crop, Compress, Strip metadata). Choosing a tool opens one **image editor window** with that tool preselected: a live preview in the middle, a tool sidebar on the right, and Save/Cancel at the bottom. Tools can be combined in one pass (for example crop, then frame). Save writes a new file next to the original; the original is never touched.

**Frame** turns an image into a presentable card: rounded corners, border, shadow, an optional macOS window frame with red/yellow/green buttons, and a background/margin. Styles are saved as named presets.

## Goals

- Frame with rounded corners, border (colour, thickness), shadow, optional macOS window chrome, background/margin.
- Named Frame presets with a default preset, edited in the editor and stored in settings.
- Crop with a draggable rectangle and aspect presets (free, 1:1, 4:3, 16:9).
- Compress with quality or target-size choice and a live file-size estimate.
- Strip metadata (EXIF, GPS, camera info) in one click.
- Preview and export use the same code path ("what you see is what you get").
- Same safety rules as stage 1: originals untouched, new sibling file, no overwrite, temp-then-move.

## Non-goals (deferred)

- Annotate (arrows, boxes, text, redaction) and QR reading.
- Tool menu items for PDF and video tools (stage 3).
- Applying different settings per image in a multi-file batch.
- Animated images: only the first frame is edited.
- Lossless PNG optimisation (palette reduction, zopfli).

## Architecture

New and changed units.

1. **EditCore** (new SwiftPM library target, no UI; depends on nothing but CoreGraphics/ImageIO)
   - `EditStep` protocol: a value-type step that takes a `CGImage` and returns a `CGImage` (`func apply(to: CGImage, scale: CGFloat) throws -> CGImage`). `scale` is the ratio of the image being processed to the full-resolution original, so a downscaled preview renders the same geometry as the export.
   - Steps: `CropStep`, `FrameStep` (composed of the five sub-effects below).
   - `EditPipeline`: an ordered list of steps (`crop` then `frame`; fixed order) plus an `ExportSettings` value; `render(image:) -> CGImage` for preview and `export(source:to:)` for saving.
   - `ExportSettings`: output format (`png` when Frame is on; otherwise the source format if ImageIO can write it — jpeg, png, heic, tiff, bmp, gif; a WebP source falls back to PNG and the editor says so), `quality: Double`, optional `targetBytes: Int?`, `stripMetadata: Bool`.
   - `ImageWriter`: writes a `CGImage` with ImageIO, applying quality, metadata stripping, and (for target size) a bounded search over quality.
   - `FramePreset`: `Codable` description of a Frame style (see below); `FramePresetStore` persists the presets in `UserDefaults` as JSON.
2. **ImageEditor** (new files in the `ShapeshiftApp` target)
   - `ImageEditorWindow` (SwiftUI in an `NSWindow`) with `EditorModel` (`ObservableObject`): source image(s), selected tools, tool settings, a downscaled preview image, and the current estimated output size.
   - Preview renders on a background task with debouncing; the latest request wins.
   - Save runs the pipeline for every selected file through a job runner that mirrors stage 1 (cancellable, temp-then-move, notifications).
3. **Tool menu and trigger** (changes in `ShapeshiftApp`)
   - `DragMonitor` also detects the tools trigger (default Shift+Option, already in `SettingsStore`). Both triggers are exact-match, so they never fire together.
   - A second panel type, `ToolPanel`, shows the four tools as drop targets (same behaviour as the format panel, including arrow/Enter/Escape). Only images show it in stage 2; other kinds show nothing for the tools trigger.
4. **Conversion integration:** Save reuses `OutputPlanner` for sibling names (for example `photo framed.png`, `photo cropped.jpg`, `photo compressed.jpg`, `photo clean.jpg`; combined tools join the labels, for example `photo cropped framed.png`) and the temp-then-move logic in `ConversionService`. If duplication appears, the temp-then-move block is extracted into one shared helper rather than copied.

### Data flow

Shift+Option-drag → tool panel → drop on a tool → editor window (files loaded, tool preselected) → user adjusts, preview updates → Save → pipeline runs per file → sibling file written → notification.

## Frame details

Applied in this order, each independently toggleable:

1. **Rounded corners:** `cornerRadius` in points at 1x (0 to half the shorter side); clips the image.
2. **Border:** `borderColor`, `borderWidth`; drawn inside the clip so the shape is preserved.
3. **Window frame:** `windowChrome: Bool`, `theme: light | dark`, `title: String`, `inactive: Bool`. Adds a title bar above the image with the three traffic-light buttons on the left, as in macOS. The rounded corners and border then follow the window shape, not the bare image.
4. **Shadow:** `offsetX`, `offsetY`, `blur`, `color`, `opacity`; drawn outside the shape. The canvas grows automatically so the shadow is never clipped.
5. **Background and margin:** `backgroundColor` (transparent by default), `margin`.

All lengths are specified for a 1x image and multiplied by `scale` and by the image's pixel density, so a retina screenshot gets proportionally thicker borders than a small image. Frame output is always PNG.

`FramePreset` = name + the values above. Built-in presets (not deletable): "Clean card" (radius 16, soft shadow, transparent), "Window" (window chrome, light theme, shadow), "Floating" (radius 24, strong shadow, 48 margin). User presets can be added, renamed, deleted and set as default.

## Other tools

- **Crop:** `CropStep(rect in image pixels)`. The editor shows a draggable/resizable rectangle with aspect presets (free, 1:1, 4:3, 16:9, original). The rect is stored in normalized coordinates so it applies to every image in a multi-file batch (each crops the same relative region).
- **Compress:** applies to jpeg and heic outputs (the lossy formats ImageIO can write; WebP sources are not compressible in stage 2 — the hint says to convert to JPEG first). Modes: quality slider, or target size in KB/MB (bounded binary search over quality, max 8 iterations, reports "target not reachable" if even quality 0.05 is larger). PNG is lossless in ImageIO, so Compress is disabled for PNG with the hint "PNG is lossless — convert to JPEG or WebP to shrink the file". The live size estimate encodes the preview-sized image and extrapolates; the exact size appears after Save.
- **Strip metadata:** writes the pixels without EXIF/GPS/TIFF/IPTC dictionaries. Orientation is applied to the pixels first, so rotated photos do not turn sideways.

## Error handling

- Unreadable or unsupported image: the editor shows the error and disables Save; other files in a batch still open.
- Very large images: the preview uses a downscaled copy (longest side 1600 px); export always uses the full image.
- Save follows stage 1: temp file first, move on success, never overwrite (`name 2.ext`), cleanup on failure and on cancellation. Closing the window while saving cancels the job.
- One failing file in a batch does not stop the rest; a summary notification lists failures.
- Quitting the app during a save cancels and cleans up (same mechanism as stage 1).

## Testing

- **EditCore:** XCTest with generated fixture images. Frame steps are checked against reference images with a small per-channel tolerance (CoreGraphics output can differ by a few levels across OS versions): corner radius (transparent corner pixels, opaque centre), border (known pixel colours on the edge), shadow (non-zero alpha outside the shape, canvas grew by the expected amount), window chrome (title bar height, button colours at known pixels), preview/export parity (render at scale 0.5 equals export scaled down within tolerance).
- **Crop:** output dimensions and pixel content for known rectangles; normalized rect applied to images of different sizes.
- **Compress/strip:** smaller quality gives a smaller file; target-size mode lands at or under the target or reports unreachable; stripped output has no EXIF/GPS dictionaries (checked via `CGImageSourceCopyPropertiesAtIndex`); orientation baked in.
- **Presets:** round-trip through JSON; built-ins cannot be deleted; default preset selection persists (isolated `UserDefaults` suite, cleaned up).
- **Never modifies the original:** checked for every tool (content hash before/after).
- **UI:** manual checklist per tool (preview updates, crop handles, Save writes `photo framed.png`, cancel on close, multi-file).

## Open questions

- Window chrome artwork: draw the traffic-light buttons with plain CoreGraphics circles (planned) or use bundled vector assets. Decide in planning; plain circles are enough unless they look off in review.
- Whether the tool panel should also offer "Convert…" so one Shift+Option gesture covers everything. Not in stage 2.
