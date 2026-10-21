# Manual test checklist

Hands-on checks for what automated tests cannot cover (windows, drag and drop, Finder, appearance). Work through the sections that match what you changed.

Build: `scripts/build-app.sh && open build/Shapeshift.app` (see the README for the iCloud note).

# Launch, menus and conversion

## Launch
- [ ] Menu bar icon appears, no Dock icon
- [ ] Menu shows hint line, Settings…, Quit
- [ ] Quit Shapeshift, then `open --env SHAPESHIFT_FFMPEG=/nonexistent build/Shapeshift.app`: menu says audio/video are disabled; Shift-drag of an MP3 shows no panel.

## Drag popup
- [ ] Shift-drag a PNG: panel appears beside the cursor with image formats only
- [ ] Shift-drag an MP3: audio formats only; MP4: video + GIF + audio formats
- [ ] Shift-drag a PNG and an MP3 together: no panel (no common format)
- [ ] Drag without Shift: no panel
- [ ] Release Shift mid-drag: panel disappears
- [ ] Drop on a tile: new file next to the original, original untouched
- [ ] Convert the same file twice: second output is `name 2.ext`
- [ ] Drop three PNGs at once: three outputs, one notification

## Errors
- [ ] A renamed text file `fake.png` → JPEG: "Failed" notification, no leftover `.shapeshift-*` files
- [ ] Mixed batch with one bad file: others still convert, notification says some failed

## Keys
- [ ] Settings: change convert trigger to Control; Control-drag works, Shift-drag does not; persists after relaunch
- [ ] Setting both triggers equal shows a warning and keeps the old value
- [ ] (With Input Monitoring) arrows + Return choose a tile; Escape hides the panel

## Quality
- [ ] Quality 0% vs 100% on a WAV → MP3 gives visibly different file sizes

# Frame and image tools

## Tool menu
- [ ] Shift+Option-drag a PNG: a panel with four tiles (Frame, Crop, Compress, Strip metadata) appears
- [ ] Shift-drag still shows the format panel (not the tool panel); switching between Shift and Shift+Option mid-drag swaps the panels
- [ ] Shift+Option-drag an MP3 or a mix of an image and a video: no panel
- [ ] Arrow keys + Return pick a tool (with Input Monitoring); Escape hides the panel
- [ ] Rebind the tools trigger in Settings: the new keys open the tool panel, the old ones do not
- [ ] The menu hint mentions both triggers

## Editor window
- [ ] Dropping on Frame opens the editor with Frame enabled and the default style applied
- [ ] Preview updates while moving sliders (corner radius, border, shadow, margin, background)
- [ ] Window frame: traffic-light buttons, light/dark theme, title text, inactive buttons
- [ ] Preview matches the saved file (compare a zoomed screenshot with the exported PNG)
- [ ] "Save as style…", picking a style, "Make default", "Delete" (user styles only; built-ins cannot be deleted)
- [ ] Crop: rectangle and corner handles drag smoothly, aspect presets keep their ratio, the saved file has the cropped content
- [ ] Compress on a JPEG: quality slider changes the estimated size; target size lands at or under the target; PNG shows the "lossless" hint
- [ ] Strip metadata: the saved JPEG has no GPS/EXIF (check with `mdls` or Preview's inspector); rotated photos stay upright

## Saving
- [ ] Save writes `name framed.png` (or `cropped`, `compressed`, `clean`, or combined labels) next to the original; the original is unchanged
- [ ] Saving twice gives `name framed 2.png`
- [ ] A notification appears; clicking it reveals the file
- [ ] The notification title says "Done" (one file) or "Done — N files"
- [ ] Multi-file: select 3 images, Shift+Option-drag, Save once: three outputs with the same settings
- [ ] A corrupt image in a batch fails alone with a clear message
- [ ] Quit during a save leaves no `.shapeshift-*` files
- [ ] Target size: type a value then click Save WITHOUT pressing Return — the output honours the new value
- [ ] Return in the KB or Title field does not save; ⌘S saves
- [ ] Rename a user style
- [ ] A batch with one unreadable file: the editor still opens and the others save
- [ ] A Display P3 screenshot framed keeps its colours (compare before/after)
- [ ] A WebP source saves as PNG and the editor says so
- [ ] A GIF/TIFF/HEIC source with transparency, cropped, keeps transparency
- [ ] Quit during a large save leaves no `.shapeshift-*` files

## Rough edges worth a look
- [ ] Switching to Crop briefly shows the previous (framed) preview under the crop rectangle for a moment; confirm it settles to the original image with the rectangle aligned.
- [ ] With a PNG first in a multi-file batch the Compress hint says "PNG is lossless" even though JPEGs in the batch are compressible; Save still works.
- [ ] Crop corner handles are small (14 pt): check they are easy to grab.
- [ ] After dragging a slider, the style picker still shows the chosen style's name even though the style is modified.

# Finder right-click

- [ ] After launching the built app once, right-click an image in Finder: "Shapeshift…" is at the bottom of the menu, inline or under Services
- [ ] If missing: Settings › Finder › "Refresh services", and the Keyboard Shortcuts pane lists Shapeshift under Files and Folders
- [ ] The popup opens next to the mouse, stays on screen near the edges, shows "Convert to" and "Tools" rows for an image
- [ ] Clicking a format converts (sibling file + notification); clicking a tool opens the editor with that tool selected
- [ ] Arrow keys, Return and Esc work without Input Monitoring granted
- [ ] Clicking elsewhere / switching apps closes the popup
- [ ] Invoke from Finder while the Settings or editor window is open: popup stays open
- [ ] An audio or video selection shows only "Convert to"; mixed image + audio shows only common formats and no tools
- [ ] Multi-file selection: title says "N files" and the whole selection is converted
- [ ] Selecting a folder only: nothing happens (no crash)
- [ ] Works when Shapeshift is not running (the action launches it)
- [ ] Shift-drag popups still work exactly as before
- [ ] After choosing a format or tool, or pressing Esc, focus returns sensibly (Finder is not left without an active window)

# Glass design and wheel menus

- [ ] Window frame on: Border width / colour are hidden; the exported PNG has a thin dark (light theme) or light (dark theme) outline, no user border
- [ ] Editor, Settings and pickers use glass (Liquid Glass on macOS 26); corners are rounded; the editor title bar is transparent and nothing sits under the traffic lights
- [ ] A transparent PNG shows the frosted surface behind it (no checkerboard); Settings › Appearance › Checkerboard brings the checkerboard back
- [ ] Menu style "Two rings": Shift-drag a file — a wheel appears centred on the pointer; Two rings shows formats and tools for both triggers (Two steps keeps one kind per trigger); drop on a slice converts/opens the editor
- [ ] Menu style "Split ring": formats centred at the top, a gap, then tools (Finder popup); drops work
- [ ] Menu style "Two steps": Shift-drag and Shift+Option-drag show a single ring (one kind each); the Finder popup shows Convert / Tools slices — click or Return opens one, Esc goes back, Esc again closes
- [ ] Menu style "Classic grid": the old box (now glass) still works from Shift-drag and Finder
- [ ] Wheel near a screen edge and on a second display stays fully on screen
- [ ] Clicking outside the Finder wheel closes it; clicks outside the drag wheel do nothing odd
- [ ] Arrow keys, Return and Esc work in every style (drag: needs Input Monitoring; Finder: does not)
- [ ] Glass renders inside the non-activating drag panels (if it looks flat/inactive, note it)
- [ ] The dragged file icon does not hide the centre capsule text unusably
- [ ] Changing Transparent image preview applies to the next editor window you open
- [ ] Releasing a Shift-drag immediately, without moving, drops on the centre capsule and does nothing — move onto a slice first
- [ ] Crop: dragging the crop box or its handles never moves the editor window
- [ ] Editor window cannot be made smaller than its layout; the bottom bar stays visible at the minimum size

# Pie wheel and Settings

- [ ] The wheel is a ring of glass slices with even gaps and softly rounded corners (compare with the reference screenshot); the highlighted slice is accent-coloured
- [ ] Centre capsule shows the current format and size (e.g. "PDF · 1.1 MB") before anything is highlighted; the dragged file icon sits over it
- [ ] Hover, target with a dragged file, or arrow to a conversion slice: the capsule switches to the new format and "~size" (images), "…" briefly while computing; audio/video show the format name with the source size
- [ ] Tool slices show the tool name and "Edit"
- [ ] Two rings: tools ring inside, formats outside; 12 targets (video) still fit with readable labels
- [ ] Split ring / Two steps (Finder) / Classic grid still work; slices are fully clickable and drop targets (corners and gaps behave sensibly)
- [ ] Settings opens as a normal resizable window with General / Appearance / Finder & keys / Tools tabs; no tab needs scrolling at the default size
- [ ] General shows "Default 85 %" and "Reset to 85 %" works; the quality slider still changes conversions
- [ ] Drop a file on EVERY slice in each menu style (Shift-drag): it converts to that slice's format, and the capsule names the slice under the pointer; hover/click/drop respect the slice shapes and gaps (test on macOS 26 and on 13–15). The wheel now uses a single interaction layer (one onContinuousHover + one DropDelegate with a pure WheelLayout.item(at:) hit test); if the lit slice still looks offset during a drag, the fallback is an AppKit NSView drop target using draggedImageLocation.
- [ ] Hovering out of a slice returns the capsule to the current format and size

# Combined wheel, hit-testing and glass

- [ ] Menu style Two rings: Shift-drag AND Shift+Option-drag of an image show the same wheel — formats in the outer ring, tools in the inner ring
- [ ] Menu style Split ring: the same combined wheel from both triggers, formats centred at the top, a gap, then tools
- [ ] A PDF/audio/video drag shows only formats in those styles (no tools exist)
- [ ] Two steps and Classic grid: Shift shows formats, Shift+Option shows tools, as before; Settings explains each style under the picker
- [ ] Holding a file over a slice lights exactly that slice, also close to gaps, ring borders and the top; the capsule names it and previews the size; dropping converts to THAT format
- [ ] Hover without a file lights the slice under the pointer; moving over the centre or outside clears it; clicking a slice works in the Finder popup
- [ ] Settings › Appearance › Glass style (macOS 26+ only): Liquid Glass / Frosted change the glass surfaces (wheel, popups) immediately; the editor always uses frosted cards
- [ ] SVG: drop an .svg → PNG/JPG etc. works and Frame/Crop open it; PNG → SVG writes a file that embeds the pixels (not a vector trace)
- [ ] On macOS 26+ Settings gains the soft colourful backdrop (no glass cards there); the editor and wheel show the glass style, without a flat frosted layer behind them
- [ ] Arrow-key selection in the Finder popup and during a Shift-drag survives small mouse movements (Return acts on the arrowed slice)
- [ ] Releasing over the centre capsule or a gap does not drop the file into Finder behind the wheel
- [ ] If it still looks like plain frost: send screenshots of the wheel and the editor

# PDF, documents and SVG

- [ ] DOCX/RTF/HTML/TXT → PDF: the PDF opens in Preview with all text; a long document gets several pages. A `.gdoc` file gives the "download as DOCX" message
- [ ] PDF → TXT gives the text; a scanned PDF reports that it has no text
- [ ] PDF (several pages) → PNG/JPG creates a folder `<name> pages` with one image per page; one-page PDF gives a single image next to it
- [ ] Wheel/Finder popup with a PDF selected shows Pages, Split, Redact in the tools ring (plus Merge with two or more files); with a PDF and an image selected only Merge
- [ ] Pages: drag a page onto another to reorder (blue bar shows where it lands), rotate, delete; Save is disabled until something changed; the result is `<name> edited.pdf` and the original is untouched
- [ ] Split: "Every page" and ranges (`1-3, 4-10`) show a count; bad ranges show a red message; result is a folder `<name> parts`
- [ ] Merge: reorder and remove files in the list; a PDF plus a PNG merges; result is `<first name> merged.pdf`
- [ ] Redact: draw boxes on several pages, undo, right-click a box to remove it; the confirmation appears; open the result in Preview and try to select/copy the text under a box — it must be gone; pages without boxes still have selectable text
- [ ] Password-protected or broken PDFs give a readable error and leave no stray `.shapeshift-*` files

# Window background and selection colour

- [ ] Settings, the editor and the PDF tool windows have the frosted (blurred) window background again, with no gradient
- [ ] Settings › Appearance › Selected slice colour: System accent / Lighter / Darker / Custom colour change the highlighted wheel slice immediately; the label stays readable (dark text on light fills)

# Start at login and About

- [ ] Settings › General › Start Shapeshift at login: switch on, log out and in (or reboot); Shapeshift is running in the menu bar
- [ ] If macOS needs approval, a caption says "Approve Shapeshift in System Settings › General › Login Items" and an "Open Login Items settings" button opens that pane; the toggle reflects the real state after reopening Settings and after changing it in System Settings
- [ ] Switching it off removes Shapeshift from Login Items
- [ ] Status bar menu › About Shapeshift shows the icon, version 1.0.0 and "Local file converter and tools"
- [ ] Settings › Tools shows "Shapeshift 1.0.0" (under `swift run`: "Shapeshift dev")
