import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// An RGBA colour with components in 0...1.
public struct RGBAColor: Codable, Equatable, Sendable {
    public var r: Double, g: Double, b: Double, a: Double
    public init(r: Double, g: Double, b: Double, a: Double = 1) { self.r = r; self.g = g; self.b = b; self.a = a }
    public static let clear = RGBAColor(r: 0, g: 0, b: 0, a: 0)
    public static let black = RGBAColor(r: 0, g: 0, b: 0, a: 1)
    public static let white = RGBAColor(r: 1, g: 1, b: 1, a: 1)
    /// The colour as a CGColor in sRGB.
    public var cgColor: CGColor { CGColor(srgbRed: r, green: g, blue: b, alpha: a) }
}

/// `scale` is processed size / full size (1 at export). `referenceLongSide` is the longest side, in pixels,
/// of the full-size image the step operates on. Lengths in styles are multiplied by `unit`.
public struct EditContext: Equatable, Sendable {
    public var scale: CGFloat
    public var referenceLongSide: Int
    public init(scale: CGFloat, referenceLongSide: Int) { self.scale = scale; self.referenceLongSide = referenceLongSide }
    /// Multiplier for style lengths: scale times the longest side in thousands of pixels, but never less than scale.
    public var unit: CGFloat { scale * max(1, CGFloat(referenceLongSide) / 1000) }
}

/// Errors raised while loading, rendering, writing or fitting an image.
public enum EditError: Error, LocalizedError, Equatable, Sendable {
    case unreadable(String)
    case renderFailed(String)
    case writeFailed(String)
    case targetNotReachable

    /// User-facing message for each case.
    public var errorDescription: String? {
        switch self {
        case .unreadable(let name): return "Could not read \(name)."
        case .renderFailed(let what): return "Could not render the image (\(what))."
        case .writeFailed(let what): return "Could not write the image (\(what))."
        case .targetNotReachable: return "The target size cannot be reached, even at the lowest quality."
        }
    }
}

/// Image formats the exporter can write.
public enum ImageOutputFormat: String, CaseIterable, Codable, Sendable {
    case jpeg, png, heic, tiff, bmp, gif

    /// The UTType ImageIO uses to create a file of this format.
    public var utType: UTType {
        switch self {
        case .jpeg: return .jpeg
        case .png: return .png
        case .heic: return .heic
        case .tiff: return .tiff
        case .bmp: return .bmp
        case .gif: return .gif
        }
    }
    public var fileExtension: String { self == .jpeg ? "jpg" : rawValue }
    /// Whether the format has a quality setting (JPEG and HEIC).
    public var isLossy: Bool { self == .jpeg || self == .heic }
    /// Formats for which we copy EXIF/GPS/TIFF/IPTC from the source when metadata is kept.
    public var supportsMetadata: Bool { self == .jpeg || self == .heic || self == .tiff }

    /// Format for an extension (case-insensitive; accepts jpe, tif and heif). Nil if unsupported.
    public init?(fileExtension ext: String) {
        switch ext.lowercased() {
        case "jpg", "jpeg", "jpe": self = .jpeg
        case "tif", "tiff": self = .tiff
        case "heic", "heif": self = .heic
        default:
            guard let match = ImageOutputFormat(rawValue: ext.lowercased()) else { return nil }
            self = match
        }
    }
}

/// A rectangle in 0...1 coordinates with a top-left origin.
public struct NormalizedRect: Codable, Equatable, Sendable {
    public var x: Double, y: Double, width: Double, height: Double
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
    /// The whole image.
    public static let full = NormalizedRect(x: 0, y: 0, width: 1, height: 1)

    /// Pixel rect (top-left origin), rounded, at least 1x1, always inside the image.
    public func pixelRect(in size: CGSize) -> CGRect {
        let w = Int(size.width), h = Int(size.height)
        let px = min(max(Int((x * Double(w)).rounded()), 0), w - 1)
        let py = min(max(Int((y * Double(h)).rounded()), 0), h - 1)
        let pw = min(max(Int((width * Double(w)).rounded()), 1), w - px)
        let ph = min(max(Int((height * Double(h)).rounded()), 1), h - py)
        return CGRect(x: px, y: py, width: pw, height: ph)
    }
}

/// One stage of an edit pipeline that transforms a CGImage.
public protocol EditStep: Sendable {
    /// Returns the transformed image; throws EditError on failure.
    func apply(to image: CGImage, context: EditContext) throws -> CGImage
}
