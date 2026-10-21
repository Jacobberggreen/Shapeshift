# Shapeshift — Design

Date: 2026-10-19
Status: Historical. The original plan; the shipped scope differs: video tools, archives and text/subtitle conversion were dropped, and PDF tools, SVG and document-to-PDF were added. See [README](../../README.md) and [ARCHITECTURE](../ARCHITECTURE.md) for what exists.

## Summary

Shapeshift is a native macOS menu bar app that converts and edits files locally. Hold a configurable key while dragging a file and a popup offers target formats; a second key combination opens editing tools. A Finder right-click action does the same. Everything runs on the Mac, no files are uploaded.

It is inspired by the Mac app Tangerine (Leap Studio) but is an independent implementation with its own name, code and additions (notably the **Frame** tool).

Primary use: personal. Secondary goal: open source on GitHub later, so licensing of bundled tools and a clean structure matter from the start.

## Goals

- Convert between common image, audio, video and document formats.
- Edit files with a set of small tools (crop, compress, strip metadata, PDF split/reorder/merge, video trim, and so on).
- **Frame**: turn an image into a presentable "card" with rounded corners, border, shadow and an optional macOS window frame (traffic-light buttons), similar to a macOS screenshot.
- Trigger by Shift-drag popup and Finder right-click; trigger key is user-configurable.
- Never modify the original file.

## Non-goals

- Mac App Store distribution and sandboxing (not sandboxed; may revisit if the project is ever sold).
- Windows/Linux, web, cloud processing, accounts, telemetry.
- Intel Macs are not a priority (Apple Silicon, macOS 13+).

## Architecture

Four units with clear boundaries.

1. **ConversionCore** (Swift Package, no UI)
   - Input: a file URL and a target format. Output: a new file URL.
   - Holds the format table (source type → possible targets) and chooses an engine through a shared `Converter` protocol.
   - Depends only on the engines, never on UI.
2. **EditCore** (Swift Package, no UI)
   - Same input/output shape for editing tools, each tool a small unit with typed options.
   - Contains the Frame pipeline.
3. **Engines** (behind `Converter` / tool protocols)
   - Images: ImageIO / CoreGraphics (built in).
   - Audio and video: ffmpeg (bundled binary or found in Homebrew).
   - Documents: PDFKit where sufficient, pandoc for text/Markdown/DOCX.
   - New engines can be added without touching callers.
4. **App** (SwiftUI + AppKit, menu bar app)
   - Menu bar icon, settings window, progress and result notifications.
   - Shift-drag popup: global drag and modifier-key monitoring shows a target picker at the cursor (arrow keys to choose, Enter to apply, Escape to cancel).
   - Configurable trigger keys stored in `UserDefaults` (defaults: Shift for conversion, Shift+Option for tools; both rebindable).
   - **Finder integration**: Quick Action or Finder Sync extension adding "Convert to…", forwarding files to the main app.

### Data flow

Trigger (Shift-drag, Finder, menu bar) → selected files → user picks target format or tool → ConversionCore / EditCore picks engine → output written next to the original → notification with "Show in Finder".

## Features by stage

### Stage 1 — Core conversion

- ConversionCore with images, audio and video.
- Menu bar app with Shift-drag popup and rebindable trigger key.
- Settings: trigger keys, default output quality, output location behaviour.
- Permission onboarding (see Error handling).

### Stage 2 — Frame and image tools

- **Frame** tool, a chain of independently toggleable steps:
  1. Rounded corners (radius)
  2. Border (colour, thickness)
  3. Shadow (offset, blur, colour, opacity)
  4. macOS window chrome with red/yellow/green buttons and optional title
  5. Background / padding (transparent PNG by default)
- Saved presets (for example "My screenshot style") and a default preset.
- Image tools: crop, compress, strip metadata, annotate, QR read.

### Stage 3 — Documents, archives and Finder

- PDF: split, reorder pages, merge, redact, export to DOCX / JPG / PNG / text (page images at 300 DPI).
- Text and subtitle conversion (text → PDF/image, SRT/VTT → text).
- Archives: ZIP, TAR, GZIP (RAR read-only if licensing allows).
- Video tools: crop, trim, speed, extract audio.
- Finder right-click integration.

## Error handling

- Originals are never touched. Output is a new sibling file; name collisions become `name 2.ext`, nothing is overwritten.
- Writes go to a temporary file first and are moved into place only on success, so an interrupted run never leaves a partial file.
- Missing tools (ffmpeg, pandoc): look for a bundled copy, then Homebrew, otherwise show a clear message with install instructions.
- Missing permissions (Input Monitoring / Accessibility): a first-run guide with a button to the right System Settings pane; Finder right-click still works without it.
- Multiple files: a failure on one file does not stop the rest; a summary lists failures and reasons.
- Cancellation kills the child process and removes the temp file.

## Testing

- ConversionCore and EditCore: XCTest / Swift Testing with small fixture files (image, audio clip, short video, PDF). Assert output format, dimensions or duration, and that the original is unchanged.
- Format table: a test that every declared source→target pair has an engine.
- Frame: reference-image tests (same input and options produce the same pixels for corner radius, border, shadow, window chrome).
- UI and Shift-drag cannot be tested automatically in a useful way; each stage has a manual checklist.

## Environment (verified 2026-10-19)

- Xcode 27.0 installed; ffmpeg present at `/opt/homebrew/bin/ffmpeg`; pandoc not installed (needed from stage 3).
- No existing Mac file converter named "Shapeshift" found in a web search.

## Open questions

- Bundle ffmpeg inside the app or depend on Homebrew? Bundling is friendlier but affects licensing (LGPL/GPL build) once open sourced. Decide in stage 1 planning.
- Finder integration: Quick Action vs Finder Sync extension. Decide in stage 3.
- Open-source licence for Shapeshift itself.
