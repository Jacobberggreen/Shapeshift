import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Converts still images between the ImageIO formats and to or from SVG.
public struct ImageConverter: Converter {
    public init() {}

    static let writable: [FileFormat: UTType] = [
        .jpeg: .jpeg, .png: .png, .heic: .heic, .tiff: .tiff, .bmp: .bmp, .gif: .gif,
    ]

    /// Any image to JPEG, PNG, HEIC, TIFF, BMP, GIF or SVG, except to the same format.
    public func supports(from: FileFormat, to: FileFormat) -> Bool {
        from != to && from.kind == .image && (Self.writable[to] != nil || to == .svg)
    }

    /// Re-encodes the image with ImageIO, or goes through a bitmap for SVG input or output.
    public func convert(input: URL, from: FileFormat, to: FileFormat, output: URL, options: ConversionOptions) async throws {
        guard supports(from: from, to: to) else {
            throw ConversionError.unsupportedConversion(from: from, to: to)
        }
        if from == .svg || to == .svg {
            try convertViaBitmap(input: input, from: from, to: to, output: output, options: options)
            return
        }
        guard let type = Self.writable[to] else { throw ConversionError.unsupportedConversion(from: from, to: to) }
        guard let source = CGImageSourceCreateWithURL(input as CFURL, nil),
              CGImageSourceGetCount(source) > 0 else {
            throw ConversionError.unreadable(input)
        }
        guard let destination = CGImageDestinationCreateWithURL(output as CFURL, type.identifier as CFString, 1, nil) else {
            throw ConversionError.failed("Could not create \(to.displayName) output.")
        }
        let properties = [kCGImageDestinationLossyCompressionQuality: options.quality] as CFDictionary
        CGImageDestinationAddImageFromSource(destination, source, 0, properties)
        guard CGImageDestinationFinalize(destination) else {
            throw ConversionError.failed("Could not write \(to.displayName) file.")
        }
    }

    /// Paths that go through a decoded bitmap: SVG input is drawn by AppKit, SVG output wraps a PNG.
    private func convertViaBitmap(input: URL, from: FileFormat, to: FileFormat, output: URL, options: ConversionOptions) throws {
        let image: CGImage
        if from == .svg {
            image = try SVGSupport.rasterize(url: input)
        } else {
            guard let source = CGImageSourceCreateWithURL(input as CFURL, nil), CGImageSourceGetCount(source) > 0,
                  let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let w = props[kCGImagePropertyPixelWidth] as? Int, let h = props[kCGImagePropertyPixelHeight] as? Int,
                  let decoded = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                      kCGImageSourceCreateThumbnailFromImageAlways: true,
                      kCGImageSourceCreateThumbnailWithTransform: true,
                      kCGImageSourceThumbnailMaxPixelSize: max(w, h, 1),
                  ] as CFDictionary) else {
                throw ConversionError.unreadable(input)
            }
            image = decoded
        }
        if to == .svg {
            do { try SVGSupport.wrap(image).write(to: output) } catch let error as ConversionError { throw error } catch {
                throw ConversionError.failed("Could not write SVG file.")
            }
            return
        }
        guard let type = Self.writable[to],
              let destination = CGImageDestinationCreateWithURL(output as CFURL, type.identifier as CFString, 1, nil) else {
            throw ConversionError.failed("Could not create \(to.displayName) output.")
        }
        CGImageDestinationAddImage(destination, image,
                                   [kCGImageDestinationLossyCompressionQuality: options.quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw ConversionError.failed("Could not write \(to.displayName) file.")
        }
    }
}
