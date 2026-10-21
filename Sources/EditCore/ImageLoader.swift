import Foundation
import CoreGraphics
import ImageIO
import ConversionCore

/// A decoded preview together with the pixel size of the original.
public struct LoadedImage: @unchecked Sendable {
    public let image: CGImage
    /// Pixel size of the original file, before downscaling.
    public let fullSize: CGSize
    /// Preview width divided by original width; 1 for full-resolution loads.
    public var scale: CGFloat { CGFloat(image.width) / fullSize.width }
    public init(image: CGImage, fullSize: CGSize) { self.image = image; self.fullSize = fullSize }
}

/// Decodes image files with ImageIO, rasterising SVG through SVGSupport.
public enum ImageLoader {
    private static func isSVG(_ url: URL) -> Bool { url.pathExtension.lowercased() == "svg" }

    /// Decodes the image at full resolution with EXIF orientation applied. Throws EditError.unreadable.
    public static func loadFull(url: URL) throws -> CGImage {
        if isSVG(url) { return try SVGSupport.rasterize(url: url) }
        let source = try makeSource(url)
        let size = displaySize(of: source)
        return try thumbnail(source, maxSide: Int(max(size.width, size.height)), name: url.lastPathComponent)
    }

    /// Decodes a copy whose longest side is at most `maxSide` pixels, along with the original size.
    public static func loadPreview(url: URL, maxSide: Int = 1600) throws -> LoadedImage {
        if isSVG(url) {
            let image = try SVGSupport.rasterize(url: url, longestSide: maxSide)
            return LoadedImage(image: image, fullSize: CGSize(width: image.width, height: image.height))
        }
        let source = try makeSource(url)
        let full = displaySize(of: source)
        let longest = Int(max(full.width, full.height))
        let image = try thumbnail(source, maxSide: min(maxSide, longest), name: url.lastPathComponent)
        return LoadedImage(image: image, fullSize: full)
    }

    /// EXIF/TIFF/GPS/IPTC dictionaries safe to copy onto an edited image (orientation and pixel sizes removed).
    public static func sourceMetadata(url: URL) -> [CFString: Any] {
        guard let source = try? makeSource(url),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return [:] }
        var result: [CFString: Any] = [:]
        if var exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            exif[kCGImagePropertyExifPixelXDimension] = nil
            exif[kCGImagePropertyExifPixelYDimension] = nil
            result[kCGImagePropertyExifDictionary] = exif
        }
        if var tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
            tiff[kCGImagePropertyTIFFOrientation] = nil
            result[kCGImagePropertyTIFFDictionary] = tiff
        }
        if let gps = props[kCGImagePropertyGPSDictionary] { result[kCGImagePropertyGPSDictionary] = gps }
        if let iptc = props[kCGImagePropertyIPTCDictionary] { result[kCGImagePropertyIPTCDictionary] = iptc }
        return result
    }

    private static func makeSource(_ url: URL) throws -> CGImageSource {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), CGImageSourceGetCount(source) > 0 else {
            throw EditError.unreadable(url.lastPathComponent)
        }
        return source
    }

    private static func displaySize(of source: CGImageSource) -> CGSize {
        let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let w = props?[kCGImagePropertyPixelWidth] as? Int ?? 0
        let h = props?[kCGImagePropertyPixelHeight] as? Int ?? 0
        let orientation = props?[kCGImagePropertyOrientation] as? Int ?? 1
        return (5...8).contains(orientation) ? CGSize(width: h, height: w) : CGSize(width: w, height: h)
    }

    private static func thumbnail(_ source: CGImageSource, maxSide: Int, name: String) throws -> CGImage {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,   // bakes EXIF orientation into the pixels
            kCGImageSourceThumbnailMaxPixelSize: max(maxSide, 1),
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw EditError.unreadable(name)
        }
        return image
    }
}
