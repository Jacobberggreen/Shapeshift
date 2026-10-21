import AppKit
import CoreGraphics
import ImageIO
import PDFKit

/// "1-3, 5" style page lists, 1-based and inclusive.
public enum PageRanges {
    /// Parses a list such as "1-3, 5" into inclusive 1-based ranges, rejecting backwards or out-of-bounds ones.
    public static func parse(_ text: String, pageCount: Int) throws -> [ClosedRange<Int>] {
        let normalized = text
            .replacingOccurrences(of: "\u{2013}", with: "-")
            .replacingOccurrences(of: "\u{2014}", with: "-")
        let pieces = normalized
            .split(omittingEmptySubsequences: false, whereSeparator: { $0 == "," || $0 == ";" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !pieces.isEmpty else { throw ConversionError.failed("Enter page numbers such as 1-3, 5.") }
        return try pieces.map { piece in
            let parts = piece.split(separator: "-", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            let numbers = parts.compactMap { Int($0) }
            guard parts.count <= 2, numbers.count == parts.count, let low = numbers.first, let high = numbers.last else {
                throw ConversionError.failed("\"\(piece)\" is not a page range.")
            }
            guard low <= high else { throw ConversionError.failed("\"\(piece)\" runs backwards.") }
            guard low >= 1, high <= pageCount else {
                throw ConversionError.failed("Pages must be between 1 and \(pageCount).")
            }
            return low...high
        }
    }
}

/// One page of an edited PDF: which source page it comes from and how far it is rotated.
public struct PDFPageEdit: Equatable, Sendable {
    /// Zero-based index of the source page.
    public var sourceIndex: Int
    /// Extra rotation in degrees, a multiple of 90.
    public var rotation: Int

    public init(sourceIndex: Int, rotation: Int = 0) {
        self.sourceIndex = sourceIndex
        self.rotation = rotation
    }
}

/// Page-level PDF operations. Source documents are never modified.
public enum PDFOperations {
    /// A new document of copies of the source pages, in `edits` order. The source is not changed.
    public static func rebuild(_ document: PDFDocument, edits: [PDFPageEdit]) throws -> PDFDocument {
        guard !edits.isEmpty else { throw ConversionError.failed("No pages left to build the PDF from.") }
        let result = PDFDocument()
        for edit in edits {
            guard let page = copy(of: document, at: edit.sourceIndex) else {
                throw ConversionError.failed("Page \(edit.sourceIndex + 1) does not exist.")
            }
            page.rotation = ((page.rotation + edit.rotation) % 360 + 360) % 360
            result.insert(page, at: result.pageCount)
        }
        return result
    }

    /// Pages of PDFs in order; each image (SVG included) becomes one page.
    public static func merge(_ urls: [URL]) throws -> PDFDocument {
        let result = PDFDocument()
        for url in urls {
            for page in try pages(of: url) {
                result.insert(page, at: result.pageCount)
            }
        }
        guard result.pageCount > 0 else { throw ConversionError.failed("Nothing to merge.") }
        return result
    }

    /// One new document per range (1-based, inclusive).
    public static func split(_ document: PDFDocument, ranges: [ClosedRange<Int>]) throws -> [PDFDocument] {
        guard !ranges.isEmpty else { throw ConversionError.failed("Choose at least one page range.") }
        return try ranges.map { range in
            guard range.lowerBound >= 1, range.upperBound <= document.pageCount else {
                throw ConversionError.failed("Pages must be between 1 and \(document.pageCount).")
            }
            let part = PDFDocument()
            for index in (range.lowerBound - 1)...(range.upperBound - 1) {
                guard let page = copy(of: document, at: index) else {
                    throw ConversionError.failed("Could not read page \(index + 1).")
                }
                part.insert(page, at: part.pageCount)
            }
            return part
        }
    }

    /// One single-page range per page of `document`.
    public static func everyPage(_ document: PDFDocument) -> [ClosedRange<Int>] {
        (0..<document.pageCount).map { ($0 + 1)...($0 + 1) }
    }

    /// Pages with boxes are flattened to bitmaps with black rectangles over the boxes, so the text under them is gone.
    /// Boxes are normalised 0...1 rectangles with a top-left origin, clamped to the page.
    public static func redact(_ document: PDFDocument, boxes: [Int: [CGRect]]) throws -> PDFDocument {
        let result = PDFDocument()
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else {
                throw ConversionError.failed("Could not read page \(index + 1).")
            }
            let rects = boxes[index] ?? []
            let output = rects.isEmpty ? copy(of: document, at: index) : try flatten(page, redacting: rects)
            guard let output else { throw ConversionError.failed("Could not read page \(index + 1).") }
            result.insert(output, at: result.pageCount)
        }
        return result
    }

    /// Writes `document` as "<name> <label>.pdf" next to `input`.
    public static func save(_ document: PDFDocument, nextTo input: URL, label: String) throws -> URL {
        let temp = OutputPlanner.temporarySibling(for: input.deletingPathExtension().appendingPathExtension("pdf"))
        defer { try? FileManager.default.removeItem(at: temp) }
        guard document.write(to: temp) else { throw ConversionError.failed("Could not write PDF file.") }
        return try OutputCommitter.commit(temp: temp, nextTo: input, label: label, fileExtension: "pdf")
    }

    /// Writes each part as "<name> <n>.pdf" in a folder "<name> parts" next to `input`.
    public static func savePartsFolder(_ parts: [PDFDocument], nextTo input: URL) throws -> URL {
        guard !parts.isEmpty else { throw ConversionError.failed("Nothing to save.") }
        let fileManager = FileManager.default
        let temp = input.deletingLastPathComponent().appendingPathComponent(".shapeshift-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: temp) }
        do {
            try fileManager.createDirectory(at: temp, withIntermediateDirectories: true)
        } catch {
            throw ConversionError.failed("Could not create the output folder.")
        }
        let base = input.deletingPathExtension().lastPathComponent
        let width = String(parts.count).count
        for (offset, part) in parts.enumerated() {
            let number = String(offset + 1)
            let padded = String(repeating: "0", count: width - number.count) + number
            let file = temp.appendingPathComponent("\(base) \(padded)").appendingPathExtension("pdf")
            guard part.write(to: file) else { throw ConversionError.failed("Could not write PDF file.") }
        }
        return try OutputCommitter.commitFolder(temp: temp, nextTo: input, suffix: "parts")
    }

    // MARK: Private

    private static func copy(of document: PDFDocument, at index: Int) -> PDFPage? {
        document.page(at: index)?.copy() as? PDFPage
    }

    private static func pages(of url: URL) throws -> [PDFPage] {
        if let format = FileFormat(url: url), format.kind == .image {
            let image: CGImage
            if format == .svg {
                image = try SVGSupport.rasterize(url: url)
            } else {
                image = try decodeImage(url)
            }
            let size = NSSize(width: image.width, height: image.height)
            guard let page = PDFPage(image: NSImage(cgImage: image, size: size)) else {
                throw ConversionError.failed("Could not add \(url.lastPathComponent).")
            }
            return [page]
        }
        guard let document = PDFDocument(url: url) else { throw ConversionError.unreadable(url) }
        if document.isLocked { throw ConversionError.failed("\(url.lastPathComponent) is password protected.") }
        return try (0..<document.pageCount).map { index in
            guard let page = copy(of: document, at: index) else { throw ConversionError.unreadable(url) }
            return page
        }
    }

    private static func decodeImage(_ url: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), CGImageSourceGetCount(source) > 0,
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int, let h = props[kCGImagePropertyPixelHeight] as? Int,
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceThumbnailMaxPixelSize: max(w, h, 1),
              ] as CFDictionary) else {
            throw ConversionError.unreadable(url)
        }
        return image
    }

    private static func flatten(_ page: PDFPage, redacting rects: [CGRect]) throws -> PDFPage {
        let photo = try PDFConverter.render(page)
        let width = photo.width
        let height = photo.height
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw ConversionError.failed("Could not create a bitmap for a PDF page.")
        }
        context.draw(photo, in: CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        let unit = CGRect(x: 0, y: 0, width: 1, height: 1)
        for rect in rects {
            let clamped = rect.standardized.intersection(unit)
            guard !clamped.isNull, !clamped.isEmpty else { continue }
            // The bitmap context has a bottom-left origin, so the top-left box edge maps to 1 - maxY.
            context.fill(CGRect(x: clamped.minX * CGFloat(width),
                                y: (1 - clamped.maxY) * CGFloat(height),
                                width: clamped.width * CGFloat(width),
                                height: clamped.height * CGFloat(height)))
        }
        guard let image = context.makeImage() else { throw ConversionError.failed("Could not redact a PDF page.") }

        let box = page.bounds(for: .mediaBox)
        let quarterTurn = page.rotation % 180 != 0
        let size = quarterTurn ? CGSize(width: box.height, height: box.width) : box.size
        guard let flattened = PDFPage(image: NSImage(cgImage: image, size: size)) else {
            throw ConversionError.failed("Could not create a redacted page.")
        }
        flattened.setBounds(CGRect(origin: .zero, size: size), for: .mediaBox)
        return flattened
    }
}
