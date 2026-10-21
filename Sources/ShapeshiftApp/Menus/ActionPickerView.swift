import AppKit
import SwiftUI
import ConversionCore

/// Popup listing the formats and tools for the dropped files.
struct ActionPickerView: View {
    @ObservedObject var model: ActionPickerModel
    let onChoose: (PickerAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.fileCount == 1 ? "Shapeshift — 1 file" : "Shapeshift — \(model.fileCount) files")
                .font(.caption).foregroundStyle(.secondary)
            if !model.formats.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Convert to").font(.caption2).foregroundStyle(.secondary)
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(64), spacing: 6),
                                             count: ActionPickerModel.columns), spacing: 6) {
                        ForEach(Array(model.formats.enumerated()), id: \.element) { index, format in
                            Button { onChoose(.format(format)) } label: {
                                Text(format.displayName)
                                    .font(.system(size: 12, weight: .semibold))
                                    .frame(width: 64, height: 36)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(fill(index)))
                                    .foregroundStyle(model.selected == index ? Color.white : Color.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            if !model.tools.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tools").font(.caption2).foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        ForEach(Array(model.tools.enumerated()), id: \.element) { offset, tool in
                            let index = model.formats.count + offset
                            Button { onChoose(.tool(tool)) } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: tool.symbolName).font(.system(size: 16))
                                    Text(tool.title).font(.system(size: 10, weight: .semibold)).lineLimit(1)
                                }
                                .frame(width: 78, height: 48)
                                .background(RoundedRectangle(cornerRadius: 8).fill(fill(index)))
                                .foregroundStyle(model.selected == index ? Color.white : Color.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(12)
        .glassSurface(cornerRadius: 18)
    }

    private func fill(_ index: Int) -> Color {
        model.selected == index ? Color.accentColor : Color.primary.opacity(0.08)
    }
}

/// A popup that can take keyboard focus (used for the Finder entry, where no drag is in progress).
@MainActor
final class KeyPanel: FormatPanel {
    var onResignKey: (() -> Void)?

    override var canBecomeKey: Bool { true }

    override func resignKey() {
        super.resignKey()
        onResignKey?()
    }

    func presentKey<Content: View>(content: Content, at mouse: NSPoint) {
        present(content: content, at: mouse)
        // The panel is non-activating, so the frontmost app keeps focus.
        makeKey()
    }

    func presentKey<Content: View>(content: Content, centeredAt mouse: NSPoint) {
        present(content: content, centeredAt: mouse)
        makeKey()
    }
}
