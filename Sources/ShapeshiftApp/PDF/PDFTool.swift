import Foundation
import ConversionCore

/// The PDF tools: pages, split, merge and redact.
enum PDFTool: String, CaseIterable, Identifiable {
    case pages, split, merge, redact
    var id: String { rawValue }
    var title: String {
        switch self {
        case .pages: return "Pages"
        case .split: return "Split"
        case .merge: return "Merge"
        case .redact: return "Redact"
        }
    }
    var symbolName: String {
        switch self {
        case .pages: return "square.grid.2x2"
        case .split: return "scissors"
        case .merge: return "rectangle.stack"
        case .redact: return "eye.slash"
        }
    }
}

/// What the tool rings and the Finder popup carry: an image edit or a PDF tool.
enum ToolKind: Hashable, Identifiable {
    case image(EditTool)
    case pdf(PDFTool)

    var id: String {
        switch self {
        case .image(let tool): return "image." + tool.id
        case .pdf(let tool): return "pdf." + tool.id
        }
    }
    var title: String {
        switch self {
        case .image(let tool): return tool.title
        case .pdf(let tool): return tool.title
        }
    }
    var symbolName: String {
        switch self {
        case .image(let tool): return tool.symbolName
        case .pdf(let tool): return tool.symbolName
        }
    }

    static func available(for urls: [URL]) -> [ToolKind] {
        let kinds = urls.map { FileFormat(url: $0) }
        guard !kinds.isEmpty, !kinds.contains(where: { $0 == nil }) else { return [] }
        let formats = kinds.compactMap { $0 }
        if formats.allSatisfy({ $0.kind == .image }) { return EditTool.allCases.map(ToolKind.image) }
        let allPDF = formats.allSatisfy { $0 == .pdf }
        if allPDF {
            return formats.count >= 2 ? [.pdf(.pages), .pdf(.split), .pdf(.merge), .pdf(.redact)]
                                      : [.pdf(.pages), .pdf(.split), .pdf(.redact)]
        }
        let mergeable = formats.allSatisfy { $0 == .pdf || $0.kind == .image }
        return mergeable && formats.count >= 2 ? [.pdf(.merge)] : []
    }
}
