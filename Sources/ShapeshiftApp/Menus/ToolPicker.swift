import SwiftUI

/// Selection state for the tool picker.
@MainActor
final class ToolPickerModel: ObservableObject {
    let tools: [ToolKind]
    let fileCount: Int
    @Published var selected: Int?

    init(tools: [ToolKind], fileCount: Int) { self.tools = tools; self.fileCount = fileCount }

    var selectedTool: ToolKind? {
        guard let selected, tools.indices.contains(selected) else { return nil }
        return tools[selected]
    }

    func move(_ direction: PickerMove) {
        guard !tools.isEmpty else { return }
        guard let current = selected else { selected = 0; return }
        switch direction {
        case .left, .up: selected = max(current - 1, 0)
        case .right, .down: selected = min(current + 1, tools.count - 1)
        }
    }
}

/// Tile grid of tools that accepts dropped files.
struct ToolPickerView: View {
    @ObservedObject var model: ToolPickerModel
    let onDrop: (ToolKind) -> Void

    private var headline: String {
        guard model.tools.contains(where: { if case .image = $0 { return true } else { return false } }) else {
            return model.fileCount == 1 ? "PDF tools" : "PDF tools for \(model.fileCount) files"
        }
        return model.fileCount == 1 ? "Edit image" : "Edit \(model.fileCount) images"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(headline)
                .font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                ForEach(Array(model.tools.enumerated()), id: \.element) { index, tool in
                    Tile(tool: tool, selected: model.selected == index, onDrop: onDrop)
                }
            }
        }
        .padding(12)
        .glassSurface(cornerRadius: 18)
    }

    private struct Tile: View {
        let tool: ToolKind
        let selected: Bool
        let onDrop: (ToolKind) -> Void
        @State private var targeted = false

        var body: some View {
            VStack(spacing: 4) {
                Image(systemName: tool.symbolName).font(.system(size: 16))
                Text(tool.title).font(.system(size: 10, weight: .semibold)).lineLimit(1)
            }
            .frame(width: 78, height: 48)
            .background(RoundedRectangle(cornerRadius: 8)
                .fill(targeted || selected ? Color.accentColor : Color.primary.opacity(0.08)))
            .foregroundStyle(targeted || selected ? Color.white : Color.primary)
            .onDrop(of: [.fileURL], isTargeted: $targeted) { _ in
                onDrop(tool)
                return true
            }
        }
    }
}
