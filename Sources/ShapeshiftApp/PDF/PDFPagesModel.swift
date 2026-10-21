import Foundation
import PDFKit
import ConversionCore
import SwiftUI

/// Page order, rotation and deletions for the pages tool, applied to one PDF.
@MainActor
final class PDFPagesModel: ObservableObject {
    let url: URL
    @Published private(set) var pages: [PDFPageEdit]
    private let document: PDFDocument?
    private var thumbnails: [Int: NSImage] = [:]
    private let originalCount: Int

    init(url: URL) {
        self.url = url
        document = PDFDocument(url: url)
        originalCount = document?.pageCount ?? 0
        pages = (0..<originalCount).map { PDFPageEdit(sourceIndex: $0) }
    }

    /// `to` is an insertion offset in the current list (0...count): the page lands before the card that was at `to`.
    func move(from: Int, to: Int) {
        guard pages.indices.contains(from), (0...pages.count).contains(to) else { return }
        let page = pages.remove(at: from)
        pages.insert(page, at: to > from ? to - 1 : to)
    }

    func rotate(at index: Int, by degrees: Int) {
        guard pages.indices.contains(index) else { return }
        pages[index].rotation = (((pages[index].rotation + degrees) % 360) + 360) % 360
    }

    func delete(at index: Int) {
        guard pages.indices.contains(index) else { return }
        pages.remove(at: index)
    }

    var edits: [PDFPageEdit] { pages }
    var canSave: Bool { !pages.isEmpty }
    var isModified: Bool { pages != (0..<originalCount).map { PDFPageEdit(sourceIndex: $0) } }

    func thumbnail(forSource index: Int) -> NSImage? {
        if let cached = thumbnails[index] { return cached }
        guard let page = document?.page(at: index) else { return nil }
        let image = page.thumbnail(of: CGSize(width: 160, height: 220), for: .mediaBox)
        thumbnails[index] = image
        return image
    }
}
