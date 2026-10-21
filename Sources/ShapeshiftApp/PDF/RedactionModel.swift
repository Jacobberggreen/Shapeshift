import Foundation
import PDFKit
import SwiftUI

/// Redaction boxes for each page, with cached preview images.
@MainActor
final class RedactionModel: ObservableObject {
    static let previewDPI: CGFloat = 150
    static let minSide: CGFloat = 0.005

    let url: URL
    let pageCount: Int
    @Published private(set) var currentPage = 0
    /// page index (0-based) -> boxes in 0...1 coordinates, top-left origin.
    @Published private(set) var boxes: [Int: [CGRect]] = [:]
    private let document: PDFDocument?
    private var previews: [Int: PreviewImage] = [:]

    /// Reference wrapper so the cache can be checked for identity.
    final class PreviewImage { let image: CGImage; init(_ image: CGImage) { self.image = image } }

    init(url: URL) {
        self.url = url
        document = PDFDocument(url: url)
        pageCount = document?.pageCount ?? 0
    }

    var totalBoxes: Int { boxes.values.reduce(0) { $0 + $1.count } }
    var pagesAffected: Int { boxes.values.filter { !$0.isEmpty }.count }
    var canSave: Bool { totalBoxes > 0 }
    var currentBoxes: [CGRect] { boxes[currentPage] ?? [] }

    func add(_ rect: CGRect) {
        let clamped = rect.standardized.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard !clamped.isNull, clamped.width >= Self.minSide, clamped.height >= Self.minSide else { return }
        boxes[currentPage, default: []].append(clamped)
    }

    func undoLast() {
        guard var list = boxes[currentPage], !list.isEmpty else { return }
        list.removeLast()
        boxes[currentPage] = list.isEmpty ? nil : list
    }

    func remove(at index: Int) {
        guard var list = boxes[currentPage], list.indices.contains(index) else { return }
        list.remove(at: index)
        boxes[currentPage] = list.isEmpty ? nil : list
    }

    func clearPage() { boxes[currentPage] = nil }
    func next() { if currentPage < pageCount - 1 { currentPage += 1 } }
    func previous() { if currentPage > 0 { currentPage -= 1 } }

    func preview(for index: Int) -> PreviewImage? {
        if let cached = previews[index] { return cached }
        guard let page = document?.page(at: index), let image = Self.render(page) else { return nil }
        let wrapped = PreviewImage(image)
        previews[index] = wrapped
        return wrapped
    }

    private static func render(_ page: PDFPage) -> CGImage? {
        let bounds = page.bounds(for: .mediaBox)
        let rotated = page.rotation % 180 != 0
        let size = rotated ? CGSize(width: bounds.height, height: bounds.width) : bounds.size
        var scale = previewDPI / 72
        let longest = max(size.width, size.height) * scale
        if longest > 4000 { scale *= 4000 / longest }
        let w = max(Int(size.width * scale), 1), h = max(Int(size.height * scale), 1)
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.scaleBy(x: CGFloat(w) / size.width, y: CGFloat(h) / size.height)
        page.draw(with: .mediaBox, to: ctx)
        return ctx.makeImage()
    }
}
