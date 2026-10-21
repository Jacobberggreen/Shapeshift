import Foundation

/// Settings that apply to every converter.
public struct ConversionOptions: Sendable, Equatable {
    /// Lossy encoding quality from 0 (smallest) to 1 (best).
    public var quality: Double

    /// Creates options; `quality` is clamped to 0...1.
    public init(quality: Double = 0.85) {
        self.quality = min(max(quality, 0), 1)
    }
}

/// Why a conversion failed. `errorDescription` is the message shown to the user.
public enum ConversionError: Error, LocalizedError, Equatable, Sendable {
    case unsupportedFile(URL)
    case unsupportedConversion(from: FileFormat, to: FileFormat)
    case toolMissing(String)
    case unreadable(URL)
    case failed(String)
    case cancelled

    /// Message for each case, written for the user.
    public var errorDescription: String? {
        switch self {
        case .unsupportedFile(let url):
            return "\(url.lastPathComponent) is not a supported file type."
        case .unsupportedConversion(let from, let to):
            return "Converting \(from.displayName) to \(to.displayName) is not supported."
        case .toolMissing(let tool):
            return "\(tool) was not found. Install it with: brew install \(tool)"
        case .unreadable(let url):
            return "Could not read \(url.lastPathComponent)."
        case .failed(let message):
            return message
        case .cancelled:
            return "Cancelled."
        }
    }
}

/// A backend that converts between some format pairs, writing to an output URL it is given.
public protocol Converter: Sendable {
    /// Whether this converter can produce `to` from `from`.
    func supports(from: FileFormat, to: FileFormat) -> Bool
    /// Writes `input` to `output` in the `to` format. Throws ConversionError on failure.
    func convert(input: URL, from: FileFormat, to: FileFormat, output: URL, options: ConversionOptions) async throws
}
