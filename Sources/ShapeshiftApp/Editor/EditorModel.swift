import Foundation
import CoreGraphics
import ImageIO
import EditCore

/// Wraps a CGImage so it can cross actor boundaries.
private struct SendableImage: @unchecked Sendable { let image: CGImage }

/// Observable state for the editor: the input files, the plan being edited and the preview.
@MainActor
final class EditorModel: ObservableObject {
    let urls: [URL]
    let presets: FramePresetStore

    @Published var plan: EditorPlan { didSet { scheduleRender() } }
    @Published var selectedTool: EditTool { didSet { scheduleRender() } }
    @Published var cropAspect: CropAspect = .free
    @Published var selectedPresetID: String?
    @Published private(set) var previewImage: CGImage?
    @Published private(set) var estimatedBytes: Int?
    @Published private(set) var errorMessage: String?
    @Published private(set) var presetList: [FramePreset]

    private(set) var originalSize: CGSize = .zero
    private var loaded: LoadedImage?
    private var renderTask: Task<Void, Never>?
    private var loadFailed = false
    /// The first readable file of the batch; it drives the preview, the source extension and the size text.
    private var previewURL: URL?

    init(urls: [URL], initialTool: EditTool, presets: FramePresetStore, baseQuality: Double) {
        self.urls = urls
        self.presets = presets
        self.presetList = presets.all
        var plan = EditorPlan()
        plan.baseQuality = baseQuality
        self.selectedTool = initialTool
        var initialPresetID: String?
        switch initialTool {
        case .frame:
            plan.frameEnabled = true
            plan.frame = presets.defaultPreset.style
            initialPresetID = presets.defaultPreset.id
        case .crop: plan.cropEnabled = true
        case .compress: plan.compressEnabled = true
        case .stripMetadata: plan.stripMetadata = true
        }
        self.plan = plan
        self.selectedPresetID = initialPresetID
        loadFirstImage()
        if initialTool == .crop, originalSize.width > 0, originalSize.height > 0 { self.plan.crop = CropGeometry.initial(aspect: .free, imageSize: originalSize) }
        scheduleRender()
    }

    var sourceExtension: String { (previewURL ?? urls.first)?.pathExtension ?? "png" }
    var isCropToolActive: Bool { selectedTool == .crop && plan.cropEnabled }
    /// True when there is no load error and at least one file in the batch has work to do under the plan
    /// (the first file's format alone must not decide: a PNG-first batch may hold JPEGs that Compress applies to).
    var canSave: Bool { errorMessage == nil && urls.contains { plan.hasWork(forExtension: $0.pathExtension) } }
    var compressAvailable: Bool { plan.outputFormat(forExtension: sourceExtension).isLossy }

    /// Previews the first READABLE file; an unreadable file elsewhere in the batch is reported per file when saving.
    private func loadFirstImage() {
        guard !urls.isEmpty else { loadFailed = true; errorMessage = "No image."; return }
        var firstError: Error?
        for url in urls {
            do {
                let loaded = try ImageLoader.loadPreview(url: url)
                self.loaded = loaded
                previewURL = url
                originalSize = loaded.fullSize
                return
            } catch {
                if firstError == nil { firstError = error }
            }
        }
        loadFailed = true
        errorMessage = firstError?.localizedDescription ?? "No image."
    }

    /// Turning Frame on with a blank, unnamed style starts from the default preset instead of drawing nothing.
    func setFrameEnabled(_ on: Bool) {
        if on, selectedPresetID == nil, plan.frame == FrameStyle() { applyPreset(presets.defaultPreset) }
        plan.frameEnabled = on
    }

    func renameSelectedPreset(to name: String) {
        guard let id = selectedPresetID, presets.preset(id: id)?.isBuiltIn == false else { return }
        presets.rename(id: id, to: name)
        presetList = presets.all
    }

    /// Bottom-bar text: output format plus an estimate, or the target ceiling in target-size mode.
    var sizeText: String {
        let format = plan.outputFormat(forExtension: sourceExtension)
        let name = format.rawValue.uppercased()
        if plan.compressApplies(to: format), case .targetBytes(let bytes) = plan.compress {
            return "\(name) · ≤ \(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file))"
        }
        if let bytes = estimatedBytes {
            return "\(name) · ≈ \(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file))"
        }
        return name
    }

    func setCropAspect(_ aspect: CropAspect) {
        cropAspect = aspect
        guard originalSize.width > 0, originalSize.height > 0 else { return }
        plan.crop = CropGeometry.initial(aspect: aspect, imageSize: originalSize)
    }

    func applyPreset(_ preset: FramePreset) {
        plan.frame = preset.style
        selectedPresetID = preset.id
    }

    func saveCurrentFrameAsPreset(name: String) {
        let added = presets.add(name: name, style: plan.frame)
        presetList = presets.all
        selectedPresetID = added.id
    }

    func deleteSelectedPreset() {
        guard let id = selectedPresetID, presets.preset(id: id)?.isBuiltIn == false else { return }
        presets.delete(id: id)
        presetList = presets.all
        selectedPresetID = nil
    }

    func makeSelectedPresetDefault() {
        if let id = selectedPresetID { presets.setDefault(id: id) }
    }

    var selectedPresetIsUser: Bool {
        guard let id = selectedPresetID else { return false }
        return presets.preset(id: id)?.isBuiltIn == false
    }

    private func scheduleRender() {
        renderTask?.cancel()
        guard let loaded else { return }
        let plan = self.plan
        let showOriginal = isCropToolActive
        let ext = sourceExtension
        let image = SendableImage(image: loaded.image)
        let full = loaded.fullSize
        let scale = loaded.scale
        renderTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 80_000_000)
            if Task.isCancelled { return }
            let result: (SendableImage?, Int?, String?) = await Task.detached(priority: .userInitiated) {
                do {
                    if showOriginal { return (image, nil, nil) }
                    let rendered = try plan.pipeline().render(image.image, fullSize: full, scale: scale)
                    var estimate: Int?
                    let format = plan.outputFormat(forExtension: ext)
                    var isTarget = false
                    if case .targetBytes = plan.compress { isTarget = true }
                    // Target-size mode: an estimate at the base quality means nothing, so none is computed.
                    if plan.compressApplies(to: format), !isTarget {
                        let pixels = Int(Double(rendered.width * rendered.height) / Double(scale * scale))
                        var quality = plan.baseQuality
                        if case .quality(let q) = plan.compress { quality = q }
                        estimate = try ImageWriter.estimateBytes(preview: rendered, fullPixelCount: pixels,
                                                                 format: format, quality: quality, metadata: nil)
                    }
                    return (SendableImage(image: rendered), estimate, nil)
                } catch {
                    return (nil, nil, error.localizedDescription)
                }
            }.value
            if Task.isCancelled { return }
            guard let self else { return }
            // This Task inherits the main actor, so state is only touched on the main thread. A render error is
            // transient (cleared by the next good render); a load failure stays.
            if let image = result.0?.image { self.previewImage = image }
            self.estimatedBytes = result.1
            if !self.loadFailed { self.errorMessage = result.2 }
        }
    }
}
