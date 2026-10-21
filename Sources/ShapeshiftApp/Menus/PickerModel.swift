import Foundation
import ConversionCore

/// Selection and keyboard navigation for the format picker.
@MainActor
final class PickerModel: ObservableObject {
    @Published var formats: [FileFormat]
    @Published var selected: Int?
    let fileCount: Int

    init(formats: [FileFormat], fileCount: Int) {
        self.formats = formats
        self.fileCount = fileCount
    }

    var selectedFormat: FileFormat? {
        guard let selected, formats.indices.contains(selected) else { return nil }
        return formats[selected]
    }

    func move(_ direction: PickerMove, columns: Int = 4) {
        guard !formats.isEmpty else { return }
        guard let current = selected else { selected = 0; return }
        let last = formats.count - 1
        switch direction {
        case .left:  selected = max(current - 1, 0)
        case .right: selected = min(current + 1, last)
        case .up:    selected = current - columns >= 0 ? current - columns : current
        case .down:  selected = current + columns <= last ? current + columns : (current / columns < last / columns ? last : current)
        }
    }
}

/// Arrow-key direction in a picker.
enum PickerMove { case left, right, up, down }
