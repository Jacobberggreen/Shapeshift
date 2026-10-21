import Foundation
import CoreGraphics
import ImageIO

/// Encodes and writes images with ImageIO, optionally carrying metadata over.
public enum ImageWriter {
    /// Encodes `image` in `format`. Quality is clamped to 0...1 and only used by lossy formats.
    public static func encode(_ image: CGImage, format: ImageOutputFormat, quality: Double,
                              metadata: [CFString: Any]?) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, format.utType.identifier as CFString, 1, nil) else {
            throw EditError.writeFailed("\(format.rawValue) destination")
        }
        var properties: [CFString: Any] = [:]
        if format.isLossy { properties[kCGImageDestinationLossyCompressionQuality] = min(max(quality, 0), 1) }
        if let metadata, format.supportsMetadata { for (key, value) in metadata { properties[key] = value } }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw EditError.writeFailed("\(format.rawValue) finalize") }
        return data as Data
    }

    /// Encodes `image` and writes the bytes to `url`, throwing EditError.writeFailed on failure.
    public static func write(_ image: CGImage, format: ImageOutputFormat, quality: Double,
                             metadata: [CFString: Any]?, to url: URL) throws {
        let data = try encode(image, format: format, quality: quality, metadata: metadata)
        do { try data.write(to: url) } catch { throw EditError.writeFailed(error.localizedDescription) }
    }

    /// Largest quality in 0.05...1 whose encoding is at most `targetBytes` (8 bisection steps).
    public static func fit(_ image: CGImage, format: ImageOutputFormat, targetBytes: Int,
                           metadata: [CFString: Any]?) throws -> (data: Data, quality: Double) {
        guard format.isLossy else { throw EditError.writeFailed("target size needs a lossy format") }
        let top = try encode(image, format: format, quality: 1, metadata: metadata)
        if top.count <= targetBytes { return (top, 1) }
        var lowQuality = 0.05
        var best = try encode(image, format: format, quality: lowQuality, metadata: metadata)
        guard best.count <= targetBytes else { throw EditError.targetNotReachable }
        var highQuality = 1.0
        for _ in 0..<8 {
            let mid = (lowQuality + highQuality) / 2
            let data = try encode(image, format: format, quality: mid, metadata: metadata)
            if data.count <= targetBytes { best = data; lowQuality = mid } else { highQuality = mid }
        }
        return (best, lowQuality)
    }

    /// Encodes the (small) preview and extrapolates by pixel count.
    public static func estimateBytes(preview: CGImage, fullPixelCount: Int, format: ImageOutputFormat,
                                     quality: Double, metadata: [CFString: Any]?) throws -> Int {
        let data = try encode(preview, format: format, quality: quality, metadata: metadata)
        let previewPixels = max(1, preview.width * preview.height)
        return Int(Double(data.count) * Double(fullPixelCount) / Double(previewPixels))
    }
}
