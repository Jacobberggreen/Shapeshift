import Foundation
import ConversionCore
import EditCore

/// Inputs for estimating a conversion's output size: source format, size and preview.
struct WheelOutcomeSource {
    var sourceFormat: FileFormat? = nil
    /// Already-known total size. Real sources leave this nil and supply `sourceBytesProvider` instead.
    var sourceBytes: Int? = nil
    var estimate: (@Sendable (FileFormat) async -> Int?)? = nil
    /// Resolves the total source size off the main thread (disk access).
    var sourceBytesProvider: (@Sendable () async -> Int?)? = nil
}

/// Decodes the preview once and hands the same image to every later estimate of the same wheel.
final class PreviewCache: @unchecked Sendable {
    private let lock = NSLock()
    private var resolved = false
    private var value: LoadedImage?
    private let decode: @Sendable () -> LoadedImage?

    init(decode: @escaping @Sendable () -> LoadedImage?) { self.decode = decode }

    func get() -> LoadedImage? {
        lock.lock(); defer { lock.unlock() }
        if !resolved { value = decode(); resolved = true }
        return value
    }
}

/// Estimates output sizes for the wheel's conversion targets, without blocking the main thread.
enum OutcomeEstimator {
    /// Cheap to build: touches no file. Sizes and the preview decode happen lazily, off the main thread.
    static func source(for urls: [URL], quality: Double,
                       sizeProvider: @escaping @Sendable (URL) -> Int? = OutcomeEstimator.fileSize,
                       previewLoader: @escaping @Sendable (URL) -> LoadedImage? = OutcomeEstimator.loadPreview) -> WheelOutcomeSource {
        let formats = Set(urls.compactMap { FileFormat(url: $0) })
        var result = WheelOutcomeSource(sourceFormat: formats.count == 1 ? formats.first : nil)
        if !urls.isEmpty {
            result.sourceBytesProvider = {
                let known = urls.compactMap(sizeProvider)
                return known.isEmpty ? nil : known.reduce(0, +)
            }
        }
        let allImages = !urls.isEmpty && urls.allSatisfy { FileFormat(url: $0)?.kind == .image }
        if allImages, let first = urls.first {
            let cache = PreviewCache { previewLoader(first) }
            result.estimate = { target in
                let total = urls.compactMap(sizeProvider).reduce(0, +)
                let firstBytes = sizeProvider(first) ?? 0
                let scale = (firstBytes > 0 && total > 0) ? Double(total) / Double(firstBytes) : 1
                return estimateBytes(preview: cache, to: target, quality: quality, scale: scale)
            }
        }
        return result
    }

    /// Encodes the shared preview in the target format and extrapolates by pixel count (images only).
    /// Runs on the caller's (background) executor and bails out between decode and encode when cancelled.
    static func estimateBytes(preview cache: PreviewCache, to target: FileFormat, quality: Double, scale: Double) -> Int? {
        guard let output = ImageOutputFormat(rawValue: target.rawValue), !Task.isCancelled,
              let loaded = cache.get(), !Task.isCancelled else { return nil }
        let pixels = Int(loaded.fullSize.width * loaded.fullSize.height)
        guard let bytes = try? ImageWriter.estimateBytes(preview: loaded.image, fullPixelCount: pixels,
                                                         format: output, quality: quality, metadata: nil) else { return nil }
        return Int(Double(bytes) * scale)
    }

    @Sendable static func fileSize(_ url: URL) -> Int? {
        try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
    }

    @Sendable static func loadPreview(_ url: URL) -> LoadedImage? {
        try? ImageLoader.loadPreview(url: url, maxSide: 800)
    }
}
