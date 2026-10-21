import Foundation
import CoreGraphics

/// Output format and encoding choices for an export.
public struct ExportSettings: Equatable, Sendable {
    public var format: ImageOutputFormat
    /// Lossy quality from 0 to 1; ignored by lossless formats.
    public var quality: Double
    /// Size budget in bytes. When set on a lossy format, the quality is searched to fit it.
    public var targetBytes: Int?
    /// Drops EXIF, GPS and IPTC metadata from the output.
    public var stripMetadata: Bool
    public init(format: ImageOutputFormat, quality: Double, targetBytes: Int?, stripMetadata: Bool) {
        self.format = format; self.quality = quality; self.targetBytes = targetBytes; self.stripMetadata = stripMetadata
    }
}

/// Renders a source image through an edit pipeline and writes it in the chosen format.
public enum EditExporter {
    /// Loads `source`, applies `pipeline` and writes `output`. Metadata is copied only when kept, supported and no frame is applied.
    public static func export(source: URL, pipeline: EditPipeline, settings: ExportSettings, to output: URL) throws {
        let full = try ImageLoader.loadFull(url: source)
        let fullSize = CGSize(width: full.width, height: full.height)
        let rendered = try pipeline.render(full, fullSize: fullSize, scale: 1)

        let keepsMetadata = !settings.stripMetadata && settings.format.supportsMetadata && pipeline.frame == nil
        let metadata: [CFString: Any]? = keepsMetadata ? ImageLoader.sourceMetadata(url: source) : nil

        if let target = settings.targetBytes, settings.format.isLossy {
            let fitted = try ImageWriter.fit(rendered, format: settings.format, targetBytes: target, metadata: metadata)
            do { try fitted.data.write(to: output) } catch { throw EditError.writeFailed(error.localizedDescription) }
        } else {
            try ImageWriter.write(rendered, format: settings.format, quality: settings.quality,
                                  metadata: metadata, to: output)
        }
    }
}
