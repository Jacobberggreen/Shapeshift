import Foundation
import PDFKit
import ConversionCore
import SwiftUI

/// Split mode and page ranges for the split tool.
@MainActor
final class PDFSplitModel: ObservableObject {
    enum Mode: Hashable { case everyPage, ranges }

    let url: URL
    let pageCount: Int
    @Published var mode: Mode = .everyPage
    @Published var rangeText = ""

    init(url: URL) {
        self.url = url
        pageCount = PDFDocument(url: url)?.pageCount ?? 0
    }

    /// nil while the input is empty or invalid.
    var ranges: [ClosedRange<Int>]? {
        guard pageCount > 0 else { return nil }
        switch mode {
        case .everyPage: return (1...pageCount).map { $0...$0 }
        case .ranges: return try? PageRanges.parse(rangeText, pageCount: pageCount)
        }
    }

    var errorMessage: String? {
        guard mode == .ranges, !rangeText.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        do { _ = try PageRanges.parse(rangeText, pageCount: pageCount); return nil }
        catch { return (error as? LocalizedError)?.errorDescription ?? "\(error)" }
    }

    var canSave: Bool { ranges != nil }

    var summary: String {
        guard let count = ranges?.count else { return "" }
        return "Will create \(count) file\(count == 1 ? "" : "s")"
    }
}
