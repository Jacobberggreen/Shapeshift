import SwiftUI
import AppKit
import EditCore

extension RGBAColor {
    var swiftUIColor: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }
    init(_ color: Color) {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .black
        self.init(r: Double(ns.redComponent), g: Double(ns.greenComponent), b: Double(ns.blueComponent),
                  a: Double(ns.alphaComponent))
    }
}

private func colorBinding(_ binding: Binding<RGBAColor>) -> Binding<Color> {
    Binding(get: { binding.wrappedValue.swiftUIColor }, set: { binding.wrappedValue = RGBAColor($0) })
}

extension View {
    /// `onChange(of:)` without the macOS 14 deprecation warning, usable on macOS 13.
    @ViewBuilder
    func onValueChange<V: Equatable>(of value: V, _ action: @escaping (V) -> Void) -> some View {
        if #available(macOS 14, *) {
            self.onChange(of: value) { _, new in action(new) }
        } else {
            self.onChange(of: value, perform: action)
        }
    }
}

/// Editor content: preview with crop and frame controls, and Save or Cancel.
struct EditorView: View {
    @ObservedObject var model: EditorModel
    let onSave: (EditorPlan) -> Void
    let onCancel: () -> Void
    var transparencyPreview: TransparencyPreview = .frosted
    @State private var targetKB: Int = 500
    @State private var targetText: String = "500"

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                preview
                    .frame(minWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .frostedCard(cornerRadius: 20)
                sidebar
                    .frame(width: 300)
                    .frostedCard(cornerRadius: 20)
            }
            bottomBar.frostedCard(cornerRadius: 18)
        }
        .padding(12)
        .frame(minWidth: 760, minHeight: 520)
    }

    // MARK: preview

    private var preview: some View {
        ZStack {
            if transparencyPreview == .checkerboard { Checkerboard() }
            if let message = model.errorMessage {
                Text(message).foregroundStyle(.red).padding()
            } else if let image = model.previewImage {
                Image(decorative: image, scale: 1)
                    .resizable().scaledToFit()
                    .overlay {   // the overlay shares the fitted image's frame, so normalised coords line up
                        if model.isCropToolActive {
                            CropOverlay(rect: $model.plan.crop, imageSize: model.originalSize,
                                        ratio: model.cropAspect.ratio(imageSize: model.originalSize))
                        }
                    }
                    .padding(16)
            } else {
                ProgressView()
            }
        }
    }

    // MARK: sidebar

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(EditTool.allCases) { tool in toolSection(tool) }
            }.padding(14)
        }
    }

    private func enabledBinding(_ tool: EditTool) -> Binding<Bool> {
        switch tool {
        case .frame: return Binding(get: { model.plan.frameEnabled }, set: { model.setFrameEnabled($0) })
        case .crop: return Binding(get: { model.plan.cropEnabled }, set: { on in
            model.plan.cropEnabled = on
            if on { model.plan.crop = CropGeometry.initial(aspect: model.cropAspect, imageSize: model.originalSize) }
        })
        case .compress: return $model.plan.compressEnabled
        case .stripMetadata: return $model.plan.stripMetadata
        }
    }

    private func toolSection(_ tool: EditTool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle(isOn: enabledBinding(tool)) {
                    Label(tool.title, systemImage: tool.symbolName).font(.headline)
                }
                Spacer()
                Button(model.selectedTool == tool ? "▾" : "▸") { model.selectedTool = tool }
                    .buttonStyle(.borderless)
            }
            if model.selectedTool == tool {
                switch tool {
                case .frame: frameControls
                case .crop: cropControls
                case .compress: compressControls
                case .stripMetadata:
                    Text("Removes EXIF, GPS, camera info. Rotation is applied to the pixels first.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Divider()
        }
    }

    private var frameControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Picker("Style", selection: Binding(
                    get: { model.selectedPresetID ?? "" },
                    set: { id in if let p = model.presetList.first(where: { $0.id == id }) { model.applyPreset(p) } })) {
                    if model.selectedPresetID == nil { Text("Custom").tag("") }
                    ForEach(model.presetList) { Text($0.name).tag($0.id) }
                }
            }
            HStack {
                Button("Save as style…") { askForPresetName() }
                if model.selectedPresetIsUser {
                    Button("Rename…") { askForPresetRename() }
                    Button("Delete") { model.deleteSelectedPreset() }
                }
                if model.selectedPresetID != nil { Button("Make default") { model.makeSelectedPresetDefault() } }
            }.font(.caption)
            slider("Corner radius", $model.plan.frame.cornerRadius, 0...80)
            if !model.plan.frame.windowChrome {
                slider("Border width", $model.plan.frame.borderWidth, 0...24)
                ColorPicker("Border colour", selection: colorBinding($model.plan.frame.borderColor), supportsOpacity: true)
            }
            Toggle("Window frame", isOn: $model.plan.frame.windowChrome)
            if model.plan.frame.windowChrome {
                Picker("Theme", selection: $model.plan.frame.theme) {
                    Text("Light").tag(WindowTheme.light); Text("Dark").tag(WindowTheme.dark)
                }.pickerStyle(.segmented)
                TextField("Title", text: $model.plan.frame.title)
                Toggle("Inactive buttons", isOn: $model.plan.frame.inactive)
            }
            Toggle("Shadow", isOn: $model.plan.frame.shadowEnabled)
            if model.plan.frame.shadowEnabled {
                slider("Offset X", $model.plan.frame.shadowOffsetX, -60...60)
                slider("Offset Y", $model.plan.frame.shadowOffsetY, -60...60)
                slider("Blur", $model.plan.frame.shadowBlur, 0...80)
                slider("Opacity", $model.plan.frame.shadowOpacity, 0...1)
                ColorPicker("Shadow colour", selection: colorBinding($model.plan.frame.shadowColor), supportsOpacity: false)
            }
            ColorPicker("Background", selection: colorBinding($model.plan.frame.backgroundColor), supportsOpacity: true)
            slider("Margin", $model.plan.frame.margin, 0...120)
            Text("Frame is saved as PNG.").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var cropControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Aspect", selection: Binding(get: { model.cropAspect }, set: { model.setCropAspect($0) })) {
                ForEach(CropAspect.allCases) { Text($0.title).tag($0) }
            }
            Text("Drag the rectangle or its corners in the preview.").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var compressControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !model.compressAvailable {
                Text("PNG is lossless — convert to JPEG or HEIC to shrink the file. (WebP sources are saved as PNG.)")
                    .font(.caption).foregroundStyle(.orange)
            }
            Picker("Mode", selection: Binding(
                get: { if case .targetBytes = model.plan.compress { return 1 } else { return 0 } },
                set: { model.plan.compress = $0 == 0 ? .quality(0.8) : .targetBytes(targetKB * 1024) })) {
                Text("Quality").tag(0); Text("Target size").tag(1)
            }.pickerStyle(.segmented)
            if case .quality(let q) = model.plan.compress {
                slider("Quality", Binding(get: { q }, set: { model.plan.compress = .quality($0) }), 0.05...1)
            } else {
                HStack {
                    Text("Target"); TextField("KB", text: $targetText).frame(width: 70)
                    Text("KB")
                }
                .onValueChange(of: targetText) { text in
                    // Parse on every keystroke so Save always sees what is typed; empty or 0 keeps the last value.
                    targetKB = TargetSizeParser.parse(text, fallback: targetKB)
                    model.plan.compress = .targetBytes(targetKB * 1024)
                }
            }
        }
    }

    private func slider(_ title: String, _ value: Binding<Double>, _ range: ClosedRange<Double>) -> some View {
        HStack { Text(title).font(.caption).frame(width: 90, alignment: .leading); Slider(value: value, in: range) }
    }

    // MARK: bottom bar

    private var bottomBar: some View {
        HStack {
            Text(model.sizeText).font(.caption).foregroundStyle(.secondary)
            Spacer()
            if model.urls.count > 1 {
                Text("\(model.urls.count) files — same settings for all").font(.caption).foregroundStyle(.secondary)
            }
            Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
            Button("Save") { onSave(model.plan) }
                .keyboardShortcut("s", modifiers: .command).disabled(!model.canSave)
        }.padding(12)
    }

    private func askForPresetName() {
        if let name = promptForText(message: "Save frame style", info: "Name for the new style:", initial: "", button: "Save") {
            model.saveCurrentFrameAsPreset(name: name)
        }
    }

    private func askForPresetRename() {
        let current = model.presetList.first(where: { $0.id == model.selectedPresetID })?.name ?? ""
        if let name = promptForText(message: "Rename frame style", info: "New name:", initial: current, button: "Rename") {
            model.renameSelectedPreset(to: name)
        }
    }

    /// Modal text prompt with the field focused; returns the trimmed text, or nil when cancelled.
    private func promptForText(message: String, info: String, initial: String, button: String) -> String? {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = info
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        field.stringValue = initial
        alert.accessoryView = field
        alert.addButton(withTitle: button); alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Transparency backdrop drawn behind the preview.
struct Checkerboard: View {
    var body: some View {
        Canvas { context, size in
            let tile: CGFloat = 12
            for row in 0..<Int(size.height / tile) + 1 {
                for col in 0..<Int(size.width / tile) + 1 where (row + col) % 2 == 0 {
                    context.fill(Path(CGRect(x: CGFloat(col) * tile, y: CGFloat(row) * tile, width: tile, height: tile)),
                                 with: .color(.gray.opacity(0.15)))
                }
            }
        }
    }
}

/// Draggable crop rectangle drawn over the preview.
struct CropOverlay: View {
    @Binding var rect: NormalizedRect
    let imageSize: CGSize
    let ratio: CGFloat?
    @State private var dragStart: NormalizedRect?

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let box = CGRect(x: rect.x * w, y: rect.y * h, width: rect.width * w, height: rect.height * h)
            ZStack(alignment: .topLeading) {
                Path { p in p.addRect(CGRect(origin: .zero, size: geo.size)); p.addRect(box) }
                    .fill(Color.black.opacity(0.45), style: FillStyle(eoFill: true))
                Rectangle().stroke(Color.white, lineWidth: 1.5).frame(width: box.width, height: box.height)
                    .offset(x: box.minX, y: box.minY)
                    .overlay(Color.clear.contentShape(Rectangle()).frame(width: box.width, height: box.height)
                        .offset(x: box.minX, y: box.minY)
                        .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .named("crop"))
                            .onChanged { value in
                                let start = dragStart ?? rect
                                dragStart = start
                                rect = CropGeometry.moved(start, by: CGSize(width: value.translation.width / w,
                                                                           height: value.translation.height / h))
                            }.onEnded { _ in dragStart = nil }))
                handle(.topLeft, at: CGPoint(x: box.minX, y: box.minY), size: geo.size)
                handle(.topRight, at: CGPoint(x: box.maxX, y: box.minY), size: geo.size)
                handle(.bottomLeft, at: CGPoint(x: box.minX, y: box.maxY), size: geo.size)
                handle(.bottomRight, at: CGPoint(x: box.maxX, y: box.maxY), size: geo.size)
            }
            .coordinateSpace(name: "crop")
        }
    }

    private func handle(_ which: CropHandle, at point: CGPoint, size: CGSize) -> some View {
        Circle().fill(Color.white).overlay(Circle().stroke(Color.black.opacity(0.4)))
            .frame(width: 14, height: 14).position(point)
            .gesture(DragGesture(coordinateSpace: .named("crop")).onChanged { value in
                let p = CGPoint(x: value.location.x / size.width, y: value.location.y / size.height)
                rect = CropGeometry.resized(rect, handle: which, to: p, ratio: ratio, imageSize: imageSize)
            })
    }
}
