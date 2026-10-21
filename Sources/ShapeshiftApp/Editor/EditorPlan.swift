import Foundation
import EditCore

/// Tools the editor can apply to each image.
enum EditTool: String, CaseIterable, Identifiable {
    case frame, crop, compress, stripMetadata
    var id: String { rawValue }
    var title: String {
        switch self {
        case .frame: return "Frame"
        case .crop: return "Crop"
        case .compress: return "Compress"
        case .stripMetadata: return "Strip metadata"
        }
    }
    var symbolName: String {
        switch self {
        case .frame: return "macwindow"
        case .crop: return "crop"
        case .compress: return "arrow.down.right.and.arrow.up.left"
        case .stripMetadata: return "eye.slash"
        }
    }
}

/// How the compress tool sizes output: by quality or by a byte target.
enum CompressMode: Equatable {
    case quality(Double)
    case targetBytes(Int)
}

/// The edits chosen in the editor for a batch: crop, frame, compression and metadata.
struct EditorPlan: Equatable {
    var cropEnabled = false
    var crop: NormalizedRect = .full
    var frameEnabled = false
    var frame = FrameStyle()
    var compressEnabled = false
    var compress: CompressMode = .quality(0.8)
    var stripMetadata = false
    var baseQuality = 0.85

    func pipeline() -> EditPipeline {
        EditPipeline(crop: cropEnabled ? CropStep(rect: crop) : nil,
                     frame: frameEnabled ? FrameStep(style: frame) : nil)
    }

    func outputFormat(forExtension ext: String) -> ImageOutputFormat {
        frameEnabled ? .png : (ImageOutputFormat(fileExtension: ext) ?? .png)
    }

    func compressApplies(to format: ImageOutputFormat) -> Bool { compressEnabled && format.isLossy }

    func exportSettings(forExtension ext: String) -> ExportSettings {
        let format = outputFormat(forExtension: ext)
        var quality = baseQuality
        var target: Int?
        if compressApplies(to: format) {
            switch compress {
            case .quality(let q): quality = q
            case .targetBytes(let bytes): target = bytes
            }
        }
        return ExportSettings(format: format, quality: quality, targetBytes: target, stripMetadata: stripMetadata)
    }

    func label(forExtension ext: String) -> String {
        let format = outputFormat(forExtension: ext)
        var parts: [String] = []
        if cropEnabled { parts.append("cropped") }
        if frameEnabled { parts.append("framed") }
        if compressApplies(to: format) { parts.append("compressed") }
        if stripMetadata { parts.append("clean") }
        return parts.joined(separator: " ")
    }

    func hasWork(forExtension ext: String) -> Bool { !label(forExtension: ext).isEmpty }
}

/// Parses the free-text target-size field (KB): digits only, spaces and other characters ignored.
enum TargetSizeParser {
    static let maxKB = 1_000_000

    static func parse(_ text: String, fallback: Int) -> Int {
        let digits = text.filter { $0.isASCII && $0.isNumber }
        guard !digits.isEmpty else { return fallback }
        guard let value = Int(digits) else { return maxKB }   // overflow: more digits than Int holds
        return value == 0 ? fallback : min(value, maxKB)
    }
}
