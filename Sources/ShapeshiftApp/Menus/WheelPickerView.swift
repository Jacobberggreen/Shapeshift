import SwiftUI
import ConversionCore

/// The radial menu: draws the sectors and handles pointer and key input.
struct WheelPickerView: View {
    @ObservedObject var model: WheelModel
    let onChoose: (PickerAction) -> Void
    @State private var appeared = false
    @State private var dwellTask: Task<Void, Never>?
    @State private var lastHit: PointerHit?

    private struct PointerHit: Equatable { var step: WheelStep; var index: Int? }

    /// Writes the pointer's slice into the selection only when the hit changed (keyed by step, as
    /// indices are reused after enter()/back()). Returns true when it changed.
    private func pointer(_ index: Int?) -> Bool {
        let hit = PointerHit(step: model.step, index: index)
        guard hit != lastHit else { return false }
        lastHit = hit
        model.selected = index
        return true
    }

    var body: some View {
        let size = model.panelSize
        ZStack {
            ZStack {
                Group {
                    ForEach(model.items) { item in
                        WheelSlice(item: item, size: size, highlighted: model.selected == item.id,
                                   onActivate: { activate(item.entry) })
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .id(model.step)
                hub
            }
            interactionLayer(size: size)
        }
        .frame(width: size.width, height: size.height)
        .scaleEffect(appeared ? 1 : 0.6)
        .opacity(appeared ? 1 : 0)
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: model.step)
        .onValueChange(of: model.step) { _ in lastHit = nil }
        .onAppear { withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) { appeared = true } }
    }

    /// The single full-panel layer that handles hover, click and file drops via pure hit-testing.
    private func interactionLayer(size: CGSize) -> some View {
        Color.black.opacity(0.001)
            .contentShape(Rectangle())
            .frame(width: size.width, height: size.height)
            .onContinuousHover { phase in
                switch phase {
                case .active(let point): _ = pointer(hit(point, size: size))
                case .ended: _ = pointer(nil)
                }
            }
            .gesture(SpatialTapGesture().onEnded { value in
                if let index = hit(value.location, size: size) { activate(model.items[index].entry) }
            })
            .onDrop(of: [.fileURL], delegate: WheelDropDelegate(
                hit: { hit($0, size: size) },
                onTarget: { target(drag: $0) },
                onDrop: { index in
                    guard model.items.indices.contains(index) else { return false }
                    activate(model.items[index].entry)
                    return true
                }))
            .accessibilityHidden(true)
    }

    /// Panel-space point (origin top-left) to the slice index under it.
    private func hit(_ point: CGPoint, size: CGSize) -> Int? {
        WheelLayout.item(at: CGPoint(x: point.x - size.width / 2, y: point.y - size.height / 2), in: model.items)
    }

    /// AppKit sends no hover events during a drag, so name the targeted item in the hub here, and
    /// open a hovered category after a 0.4 s dwell (drops land on items, not categories).
    private func target(drag index: Int?) {
        guard pointer(index) else { return }
        dwellTask?.cancel()
        dwellTask = nil
        guard let index, model.items.indices.contains(index), case .category(let category) = model.items[index].entry else { return }
        dwellTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            if !Task.isCancelled, model.selected == index { model.enter(category) }
        }
    }

    private func activate(_ entry: WheelEntry) {
        switch entry {
        case .action(let action): onChoose(action)
        case .category(let category): model.enter(category)
        }
    }

    private var hub: some View {
        VStack(spacing: 2) {
            Text(model.hubTitle).font(.system(size: 14, weight: .semibold))
            Text(model.hubDetail).font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .padding(.horizontal, 10)
        .frame(minWidth: 96, maxWidth: 2 * WheelLayout.firstInnerRadius - 20, minHeight: 52, maxHeight: 52)
        .glassSurface(in: Capsule())
        .allowsHitTesting(false)
    }
}

/// One pie slice, drawn only: the label is the glass view's content, so it is always drawn over the glass.
/// Panel-sized so the sector shape (centred in the panel) lines up with the wheel centre.
/// Pointer handling lives in the wheel's interaction layer.
private struct WheelSlice: View {
    let item: WheelItem
    let size: CGSize
    let highlighted: Bool
    let onActivate: () -> Void

    @AppStorage(SettingsStore.selectionColorModeKey) private var modeRaw = SelectionColorMode.accent.rawValue
    @AppStorage(SettingsStore.selectionColorHexKey) private var customHex = SettingsStore.defaultSelectionHex

    private var selection: SelectionStyle {
        SelectionStyle.resolve(mode: SelectionColorMode(rawValue: modeRaw) ?? .accent, customHex: customHex)
    }

    private var shape: SectorShape {
        SectorShape(sector: item.sector, gap: WheelLayout.gap, cornerRadius: WheelLayout.cornerRadius)
    }

    var body: some View {
        ZStack {
            shape.fill(selection.fill.opacity(highlighted ? 0.85 : 0))
            label
                .foregroundStyle(highlighted ? selection.label : Color.primary)
                .offset(x: item.offset.x, y: item.offset.y)
        }
        .frame(width: size.width, height: size.height)
        .glassSurface(in: shape)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onActivate() }
    }

    private var accessibilityText: String {
        switch item.entry {
        case .action(.format(let format)): return format.displayName
        case .action(.tool(let tool)): return tool.title
        case .category(let category): return category == .convert ? "Convert" : "Tools"
        }
    }

    @ViewBuilder private var label: some View {
        switch item.entry {
        case .action(.format(let format)):
            Text(format.displayName).font(.system(size: 13, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7)
        case .action(.tool(let tool)):
            Image(systemName: tool.symbolName).font(.system(size: 20))
        case .category(let category):
            VStack(spacing: 3) {
                Image(systemName: category == .convert ? "arrow.triangle.2.circlepath" : "wand.and.stars")
                    .font(.system(size: 20))
                Text(category == .convert ? "Convert" : "Tools").font(.system(size: 11, weight: .semibold))
            }
        }
    }
}

/// Maps a drag position to the wheel sector under it and handles the drop.
struct WheelDropDelegate: DropDelegate {
    let hit: (CGPoint) -> Int?
    let onTarget: (Int?) -> Void
    let onDrop: (Int) -> Bool

    func validateDrop(info: DropInfo) -> Bool { info.hasItemsConforming(to: [.fileURL]) }

    func dropEntered(info: DropInfo) { onTarget(hit(info.location)) }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        onTarget(hit(info.location))
        return DropProposal(operation: hit(info.location) == nil ? .forbidden : .copy)
    }

    func dropExited(info: DropInfo) { onTarget(nil) }

    func performDrop(info: DropInfo) -> Bool { hit(info.location).map(onDrop) ?? false }
}
