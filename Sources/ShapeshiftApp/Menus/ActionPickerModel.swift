import Foundation
import ConversionCore

/// What choosing a menu entry does: convert to a format or run a tool.
enum PickerAction: Equatable {
    case format(FileFormat)
    case tool(ToolKind)
}

/// Result of a key press in a picker: ignored, handled, close, or choose an action.
enum PickerKeyResult: Equatable {
    case ignored, handled, choose(PickerAction), close
}

/// Selection model for the Finder popup: a format grid (4 columns) followed by one row of tools.
/// `selected` indexes the formats first, then the tools.
@MainActor
final class ActionPickerModel: ObservableObject {
    static let columns = 4

    let formats: [FileFormat]
    let tools: [ToolKind]
    let fileCount: Int
    @Published var selected: Int?

    init(formats: [FileFormat], tools: [ToolKind], fileCount: Int) {
        self.formats = formats
        self.tools = tools
        self.fileCount = fileCount
    }

    private var total: Int { formats.count + tools.count }

    func action(at index: Int) -> PickerAction? {
        if formats.indices.contains(index) { return .format(formats[index]) }
        let toolIndex = index - formats.count
        if tools.indices.contains(toolIndex) { return .tool(tools[toolIndex]) }
        return nil
    }

    var selectedAction: PickerAction? {
        guard let selected else { return nil }
        return action(at: selected)
    }

    func move(_ direction: PickerMove) {
        guard total > 0 else { return }
        guard let current = selected else { selected = 0; return }
        let columns = Self.columns
        let formatCount = formats.count
        switch direction {
        case .left:
            selected = max(current - 1, 0)
        case .right:
            selected = min(current + 1, total - 1)
        case .up:
            if current < formatCount {
                if current - columns >= 0 { selected = current - columns }
            } else if formatCount > 0 {
                let column = current - formatCount
                let lastRowStart = ((formatCount - 1) / columns) * columns
                selected = min(lastRowStart + column, formatCount - 1)
            }
        case .down:
            guard current < formatCount else { return }
            let column = current % columns
            if current + columns < formatCount {
                selected = current + columns
            } else if current / columns < (formatCount - 1) / columns {
                selected = formatCount - 1
            } else if !tools.isEmpty {
                selected = formatCount + min(column, tools.count - 1)
            }
        }
    }

    func handle(keyCode: UInt16) -> PickerKeyResult {
        switch keyCode {
        case 123: move(.left); return .handled
        case 124: move(.right); return .handled
        case 125: move(.down); return .handled
        case 126: move(.up); return .handled
        case 36, 76:
            if let action = selectedAction { return .choose(action) }
            return .handled
        case 53: return .close
        default: return .ignored
        }
    }
}
