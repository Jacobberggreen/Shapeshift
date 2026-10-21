import Foundation

/// Broad category of a format, used to decide which conversions apply.
public enum MediaKind: String, Sendable, CaseIterable {
    case image, audio, video, document
}

/// A file format Shapeshift can read or write. Raw values are lowercase names, not always extensions.
public enum FileFormat: String, CaseIterable, Sendable, Hashable {
    // images
    case jpeg, png, heic, webp, tiff, bmp, gif, svg
    // audio
    case mp3, m4a, wav, flac, ogg, opus, aiff
    // video
    case mp4, mov, mkv, webm, avi
    // documents
    case pdf, txt, docx, doc, odt, rtf, html, gdoc

    /// The category this format belongs to.
    public var kind: MediaKind {
        switch self {
        case .jpeg, .png, .heic, .webp, .tiff, .bmp, .gif, .svg:
            return .image
        case .mp3, .m4a, .wav, .flac, .ogg, .opus, .aiff:
            return .audio
        case .mp4, .mov, .mkv, .webm, .avi:
            return .video
        case .pdf, .txt, .docx, .doc, .odt, .rtf, .html, .gdoc:
            return .document
        }
    }

    /// Extension for newly written files, such as `jpg` for JPEG.
    public var fileExtension: String {
        self == .jpeg ? "jpg" : rawValue
    }

    /// Name shown in menus: uppercase, except WebP and Opus.
    public var displayName: String {
        switch self {
        case .webp: return "WebP"
        case .opus: return "Opus"
        default: return rawValue.uppercased()
        }
    }

    /// Format for an extension, case-insensitive and including aliases such as jpe or tif. Nil if unknown.
    public init?(fileExtension ext: String) {
        switch ext.lowercased() {
        case "jpg", "jpeg", "jpe": self = .jpeg
        case "tif", "tiff": self = .tiff
        case "heic", "heif": self = .heic
        case "aif", "aiff": self = .aiff
        case "htm": self = .html
        default:
            guard let match = FileFormat(rawValue: ext.lowercased()) else { return nil }
            self = match
        }
    }

    /// Format for the file's extension. Nil if the extension is missing or unknown.
    public init?(url: URL) {
        self.init(fileExtension: url.pathExtension)
    }
}

/// Which formats each source format may be converted to, before checking the installed converters.
public enum FormatTable {
    /// Every format a file of `source` could in principle become. Which of
    /// these are actually available depends on the installed converters.
    public static func candidateTargets(from source: FileFormat) -> [FileFormat] {
        let images = FileFormat.allCases.filter { $0.kind == .image }
        let audio = FileFormat.allCases.filter { $0.kind == .audio }
        let video = FileFormat.allCases.filter { $0.kind == .video }
        let all: [FileFormat]
        switch source {
        case .pdf: all = [.txt, .png, .jpeg]
        case .docx, .doc, .odt, .rtf, .html, .txt: all = [.pdf]
        case .gdoc: all = []   // only a link to an online document; nothing to convert locally
        default:
            switch source.kind {
            case .image: all = (source == .svg ? images.filter { $0 != .webp } : images) + [.pdf]   // WebP is written by ffmpeg, which cannot read SVG
            case .audio: all = audio
            case .video: all = video + [.gif] + audio
            case .document: all = []
            }
        }
        return all.filter { $0 != source }
    }
}
