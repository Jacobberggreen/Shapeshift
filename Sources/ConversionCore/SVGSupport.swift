import AppKit
import ImageIO
import UniformTypeIdentifiers

/// SVG in and out. ImageIO cannot read SVG, but AppKit can draw it; there is no vector tracer on the system,
/// so writing SVG wraps a PNG of the image in an SVG file (valid everywhere, but not scalable).
public enum SVGSupport {
    /// Draws the SVG at `longestSide` pixels (default 2048, never smaller than the SVG's own size).
    public static func rasterize(url: URL, longestSide: Int = 2048) throws -> CGImage {
        guard let image = NSImage(contentsOf: url), image.size.width > 0, image.size.height > 0 else {
            throw ConversionError.unreadable(url)
        }
        let natural = image.size
        let scale = Double(max(longestSide, 1)) / Double(max(natural.width, natural.height))
        let width = max(1, Int((natural.width * scale).rounded()))
        let height = max(1, Int((natural.height * scale).rounded()))
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw ConversionError.unreadable(url)
        }
        let graphics = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        image.draw(in: NSRect(x: 0, y: 0, width: width, height: height))
        NSGraphicsContext.restoreGraphicsState()
        guard let result = context.makeImage() else { throw ConversionError.unreadable(url) }
        return result
    }

    /// An SVG document that displays `image` (embedded as a PNG) at its pixel size.
    public static func wrap(_ image: CGImage) throws -> Data {
        let png = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(png, UTType.png.identifier as CFString, 1, nil) else {
            throw ConversionError.failed("Could not create SVG output.")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw ConversionError.failed("Could not write SVG file.") }
        let (w, h) = (image.width, image.height)
        let svg = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="\(w)" height="\(h)" viewBox="0 0 \(w) \(h)">
          <image width="\(w)" height="\(h)" xlink:href="data:image/png;base64,\((png as Data).base64EncodedString())"/>
        </svg>

        """
        return Data(svg.utf8)
    }
}
