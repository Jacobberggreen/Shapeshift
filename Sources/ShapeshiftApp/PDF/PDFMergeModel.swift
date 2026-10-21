import Foundation
import PDFKit
import SwiftUI

/// Ordered list of PDFs and images to merge.
@MainActor
final class PDFMergeModel: ObservableObject {
    struct Item: Identifiable {
        let id = UUID()
        let url: URL
        let pageCount: Int
        var name: String { url.lastPathComponent }
    }

    @Published private(set) var items: [Item]
    let outputLabel = "merged"

    init(urls: [URL]) {
        items = urls.map { Item(url: $0, pageCount: PDFDocument(url: $0)?.pageCount ?? 1) }
    }

    var urls: [URL] { items.map(\.url) }
    var canSave: Bool { items.count >= 2 }

    func move(from source: IndexSet, to destination: Int) { items.move(fromOffsets: source, toOffset: destination) }
    func remove(at index: Int) {
        guard items.indices.contains(index) else { return }
        items.remove(at: index)
    }
}
