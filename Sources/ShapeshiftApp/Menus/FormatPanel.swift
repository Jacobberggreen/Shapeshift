import AppKit
import SwiftUI
import ConversionCore

/// Grid of format tiles for the format picker.
struct FormatPickerView: View {
    @ObservedObject var model: PickerModel
    let onDrop: (FileFormat) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.fileCount == 1 ? "Convert to" : "Convert \(model.fileCount) files to")
                .font(.caption).foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(64), spacing: 6), count: 4), spacing: 6) {
                ForEach(Array(model.formats.enumerated()), id: \.element) { index, format in
                    Tile(format: format, selected: model.selected == index, onDrop: onDrop)
                }
            }
        }
        .padding(12)
        .glassSurface(cornerRadius: 18)
    }

    private struct Tile: View {
        let format: FileFormat
        let selected: Bool
        let onDrop: (FileFormat) -> Void
        @State private var targeted = false

        var body: some View {
            Text(format.displayName)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 64, height: 36)
                .background(RoundedRectangle(cornerRadius: 8)
                    .fill(targeted || selected ? Color.accentColor : Color.primary.opacity(0.08)))
                .foregroundStyle(targeted || selected ? Color.white : Color.primary)
                .onDrop(of: [.fileURL], isTargeted: $targeted) { _ in
                    onDrop(format)
                    return true
                }
        }
    }
}

/// Borderless floating panel that shows the format picker at the mouse position.
@MainActor
class FormatPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: true)
        isFloatingPanel = true
        ignoresMouseEvents = false
        level = .statusBar
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func present(model: PickerModel, at mouse: NSPoint, onDrop: @escaping (FileFormat) -> Void) {
        present(content: FormatPickerView(model: model, onDrop: onDrop), at: mouse)
    }

    func present<Content: View>(content: Content, at mouse: NSPoint) {
        let hosting = NSHostingView(rootView: content)
        let size = hosting.fittingSize
        contentView = hosting
        setContentSize(size)
        hasShadow = true
        let origin = clampedOrigin(NSPoint(x: mouse.x + 28, y: mouse.y - size.height / 2),
                                   size: size, mouse: mouse)
        setFrameOrigin(origin)
        orderFrontRegardless()
    }

    func present<Content: View>(content: Content, centeredAt mouse: NSPoint) {
        let hosting = NSHostingView(rootView: content)
        let size = hosting.fittingSize
        contentView = hosting
        setContentSize(size)
        hasShadow = false
        let origin = clampedOrigin(NSPoint(x: mouse.x - size.width / 2, y: mouse.y - size.height / 2),
                                   size: size, mouse: mouse)
        setFrameOrigin(origin)
        orderFrontRegardless()
    }

    private func clampedOrigin(_ origin: NSPoint, size: NSSize, mouse: NSPoint) -> NSPoint {
        var origin = origin
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            origin.x = min(max(origin.x, visible.minX), visible.maxX - size.width)
            origin.y = min(max(origin.y, visible.minY), visible.maxY - size.height)
        }
        return origin
    }

    func dismiss() {
        orderOut(nil)
    }
}
