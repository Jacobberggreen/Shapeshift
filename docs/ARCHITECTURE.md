# Architecture

Shapeshift is a menu bar app (`LSUIElement`) built with SwiftPM: three library/app targets, one thin executable, and shell scripts that package the result.

```
Sources/
  ConversionCore/     Format-to-format conversion, no UI
  EditCore/           Image editing pipeline (Frame, Crop, Compress, metadata), no UI
  ShapeshiftApp/      The app: menus, windows, settings
    App/              Entry point, AppController, status item, Finder service, drag monitor, login item
    Menus/            Wheel, classic grid, Finder popup, outcome preview, selection colour
    Editor/           Image editor window and its model
    PDF/              PDF tool window: Pages, Split, Merge, Redact
    Settings/         Settings store and the tabbed Settings view
    Design/           Glass surface modifier and the window chrome
  Shapeshift/         Executable that starts the app
Tests/                XCTest suites, one folder per area (mirrors the sources)
Resources/            App icon (Icon Composer), status bar icon, DMG background
scripts/              build-app.sh, make-dmg.sh, make-icns.sh, make-menubar-icon.sh
docs/                 Design records, this file, manual test checklist
```

## ConversionCore

`ConversionService` takes a file URL and a target `FileFormat`, picks the first `Converter` that `supports(from:to:)`, writes to a hidden temporary sibling and commits it next to the input with a unique name (`OutputCommitter`). Nothing is ever overwritten. Converters:

| Converter | Handles |
| --- | --- |
| `ImageConverter` | Images through ImageIO; SVG in (rasterised by AppKit) and out (PNG embedded in an SVG) |
| `FFmpegConverter` | Audio, video and GIF/WebP through an external `ffmpeg` |
| `PDFConverter` | Images to PDF, PDF to TXT, PDF to PNG/JPG (a folder for several pages) |
| `DocumentConverter` | DOCX, DOC, ODT, RTF, HTML, TXT to PDF through the macOS text engine |

`FormatTable.candidateTargets` lists what a source *could* become; `ConversionService.targets(for:)` filters it by what is installed. `PDFOperations` holds the pure PDF logic (page ranges, rebuild, merge, split, redact) used by the PDF tools.

## EditCore

An `EditPipeline` runs small `EditStep`s (crop, frame) on a `CGImage`; `EditExporter` encodes the result (format, quality, target size, metadata). The Frame step draws the rounded card, border, shadow and window chrome. The editor shows a preview-resolution render and exports at full resolution.

## ShapeshiftApp

- **Triggering.** `DragMonitor` watches drags and the configured modifier keys; `AppController` shows the menu next to the pointer. The Finder entry is a macOS Service (`NSServices` in `Info.plist`) handled by `ServiceProvider`.
- **Menus.** `WheelLayout` computes pie-slice geometry and `WheelNavigator` the arrow-key movement (both pure and unit-tested); `WheelModel` holds step, selection and the centre outcome; `WheelPickerView` draws it and does the pointer hit-testing. `ToolKind` unifies image tools and PDF tools so every menu style shows whichever applies to the selected files.
- **Outcome preview.** `OutcomeEstimator` encodes a small preview off the main thread and extrapolates the size; one decoded preview is shared per wheel and in-flight work is cancelled when the selection moves on.
- **Windows.** The image editor and the PDF tool window use `GlassWindow` (frosted window background) and frosted cards; menus use `GlassSurface` (Liquid Glass on macOS 26 and later, material before).
- **Jobs.** Conversions, edits and PDF jobs run as tasks tracked by `AppController`, which drives the status item's busy indicator and posts a notification with a reveal action when finished.

## Packaging

`scripts/build-app.sh` builds the release executable, assembles `build/Shapeshift.app` (Info.plist, compiled icon, status bar icon), checks the Info.plist and signs ad hoc. `scripts/make-dmg.sh` wraps it in a disk image with a drag-to-Applications layout.
