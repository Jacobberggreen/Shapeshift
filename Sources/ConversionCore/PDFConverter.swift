import AppKit
import CoreGraphics
import ImageIO
import PDFKit
import UniformTypeIdentifiers

/// PDF to plain text (PDFKit's extracted text), PDF to PNG/JPG (one page: one image; several pages: a folder of
/// images), and single-page PDF from an image.
public struct PDFConverter: Converter {
    /// Render resolution for PDF to image, and the longest side allowed in pixels.
    static let renderDPI: CGFloat = 200
    static let maxPixelSide: CGFloat = 6000

    public init() {}

    /// PDF to text, PNG or JPEG, and any image to PDF.
    public func supports(from: FileFormat, to: FileFormat) -> Bool {
        (from == .pdf && (to == .txt || to == .png || to == .jpeg)) || (from.kind == .image && to == .pdf)
    }

    /// Dispatches to text extraction, page rendering or single-page PDF creation for the format pair.
    public func convert(input: URL, from: FileFormat, to: FileFormat, output: URL, options: ConversionOptions) async throws {
        switch (from, to) {
        case (.pdf, .txt):
            try extractText(input: input, output: output)
        case (.pdf, .png), (.pdf, .jpeg):
            try renderPages(input: input, to: to, output: output, options: options)
        case (_, .pdf) where from.kind == .image:
            try imageToPDF(input: input, from: from, output: output)
        default:
            throw ConversionError.unsupportedConversion(from: from, to: to)
        }
    }

    private func extractText(input: URL, output: URL) throws {
        guard let document = PDFDocument(url: input) else { throw ConversionError.unreadable(input) }
        if document.isLocked { throw ConversionError.failed("The PDF is password protected.") }
        guard let text = document.string, !text.allSatisfy(\.isWhitespace) else {
            throw ConversionError.failed("This PDF has no text to extract (it may be a scan).")
        }
        do {
            try Data(text.utf8).write(to: output)
        } catch {
            throw ConversionError.failed("Could not write TXT file.")
        }
    }

    /// One page writes `output` as an image. More pages make `output` a directory holding one image per page,
    /// named `<input name> <n>.<ext>` with `n` zero-padded to the width of the page count.
    private func renderPages(input: URL, to: FileFormat, output: URL, options: ConversionOptions) throws {
        guard let document = PDFDocument(url: input) else { throw ConversionError.unreadable(input) }
        if document.isLocked { throw ConversionError.failed("The PDF is password protected.") }
        let count = document.pageCount
        guard count > 0 else { throw ConversionError.failed("This PDF has no pages.") }
        let type: UTType = to == .png ? .png : .jpeg
        let quality = to == .jpeg ? [kCGImageDestinationLossyCompressionQuality: options.quality] as CFDictionary : nil

        if count == 1 {
            guard let page = document.page(at: 0) else { throw ConversionError.unreadable(input) }
            try write(try Self.render(page), to: output, type: type, properties: quality)
            return
        }

        do {
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        } catch {
            throw ConversionError.failed("Could not create the output folder.")
        }
        let base = input.deletingPathExtension().lastPathComponent
        let width = String(count).count
        for index in 0..<count {
            guard let page = document.page(at: index) else {
                throw ConversionError.failed("Could not read page \(index + 1).")
            }
            let number = String(index + 1)
            let padded = String(repeating: "0", count: width - number.count) + number
            let file = output.appendingPathComponent("\(base) \(padded)").appendingPathExtension(to.fileExtension)
            try write(try Self.render(page), to: file, type: type, properties: quality)
        }
    }

    /// Draws one page on a white sRGB bitmap at `renderDPI`, shrunk if the longest side would exceed `maxPixelSide`.
    static func render(_ page: PDFPage) throws -> CGImage {
        let box = page.bounds(for: .mediaBox)
        let quarterTurn = page.rotation % 180 != 0
        let pointWidth = quarterTurn ? box.height : box.width
        let pointHeight = quarterTurn ? box.width : box.height

        var scale = Self.renderDPI / 72
        let longest = max(pointWidth, pointHeight) * scale
        if longest > Self.maxPixelSide { scale *= Self.maxPixelSide / longest }
        let width = max(1, Int((pointWidth * scale).rounded()))
        let height = max(1, Int((pointHeight * scale).rounded()))

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw ConversionError.failed("Could not create a bitmap for a PDF page.")
        }
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: CGFloat(width) / pointWidth, y: CGFloat(height) / pointHeight)
        page.draw(with: .mediaBox, to: context)
        guard let image = context.makeImage() else {
            throw ConversionError.failed("Could not render a PDF page.")
        }
        return image
    }

    private func write(_ image: CGImage, to url: URL, type: UTType, properties: CFDictionary?) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil) else {
            throw ConversionError.failed("Could not create \(type.preferredFilenameExtension ?? "image") output.")
        }
        CGImageDestinationAddImage(destination, image, properties)
        guard CGImageDestinationFinalize(destination) else {
            throw ConversionError.failed("Could not write image file.")
        }
    }

    private func imageToPDF(input: URL, from: FileFormat, output: URL) throws {
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
        let size = NSSize(width: image.width, height: image.height)
        guard let page = PDFPage(image: NSImage(cgImage: image, size: size)) else {
            throw ConversionError.failed("Could not create PDF page.")
        }
        let document = PDFDocument()
        document.insert(page, at: 0)
        guard document.write(to: output) else {
            throw ConversionError.failed("Could not write PDF file.")
        }
    }
}
