import Foundation
import CoreGraphics
import ConversionCore

/// Top-level groups in the wheel: conversions and tools.
enum WheelCategory: Hashable { case convert, tools }
/// Where the wheel currently is: the root ring or one category.
enum WheelStep: Hashable { case root, category(WheelCategory) }
/// One wheel slot: an action or a link into a category.
enum WheelEntry: Equatable {
    case action(PickerAction)
    case category(WheelCategory)
}

/// A wheel slot with its ID, entry and sector geometry.
struct WheelItem: Identifiable, Equatable {
    let id: Int
    let entry: WheelEntry
    let sector: WheelSector
    /// Label position from the wheel centre; y grows downward (SwiftUI).
    var offset: CGPoint { sector.centroid }
}

/// Sector layout constants and calculations for the wheel's rings.
enum WheelLayout {
    static let gap: CGFloat = 6
    static let cornerRadius: CGFloat = 9
    static let firstInnerRadius: CGFloat = 78
    static let ringThickness: CGFloat = 64
    static let toolRingThickness: CGFloat = 56
    static let minArc: CGFloat = 54
    static let margin: CGFloat = 16

    private static let tau = 2 * CGFloat.pi

    static func items(style: MenuStyle, step: WheelStep, formats: [FileFormat], tools: [ToolKind]) -> [WheelItem] {
        let slices: [(WheelEntry, WheelSector)]
        switch style {
        case .classicGrid: slices = []
        case .twoRings: slices = twoRings(formats: formats, tools: tools)
        case .splitRing: slices = splitRing(formats: formats, tools: tools)
        case .twoSteps: slices = twoSteps(step: step, formats: formats, tools: tools)
        }
        return slices.enumerated().map { WheelItem(id: $0.offset, entry: $0.element.0, sector: $0.element.1) }
    }

    /// Square panel big enough for every step the style can show.
    static func panelSize(style: MenuStyle, formats: [FileFormat], tools: [ToolKind]) -> CGSize {
        let steps: [WheelStep] = style == .twoSteps ? [.root, .category(.convert), .category(.tools)] : [.root]
        let all = steps.flatMap { items(style: style, step: $0, formats: formats, tools: tools) }
        let outer = all.map(\.sector.outerRadius).max() ?? firstInnerRadius
        let side = 2 * (outer + margin)
        return CGSize(width: side, height: side)
    }

    /// The slice under `point` (relative to the wheel centre, y down), or nil over the hub / outside the rings.
    /// The visible gaps between slices belong to a slice, so there are no dead zones inside a ring.
    static func item(at point: CGPoint, in items: [WheelItem]) -> Int? {
        let radius = hypot(point.x, point.y)
        let angle = atan2(point.x, -point.y)
        let slack = gap / 2
        for (index, item) in items.enumerated() {
            let s = item.sector
            guard radius >= s.innerRadius - slack, radius <= s.outerRadius + slack else { continue }
            var delta = (angle - s.startAngle).truncatingRemainder(dividingBy: 2 * .pi)
            if delta < 0 { delta += 2 * .pi }
            if delta <= (s.endAngle - s.startAngle) + 1e-9 { return index }
        }
        return nil
    }

    // MARK: geometry

    /// Inner radius at which `count` slices sweeping `sweep` radians keep `minArc` of width at mid-radius.
    static func pushedInnerRadius(count: Int, base: CGFloat, thickness: CGFloat, sweep: CGFloat) -> CGFloat {
        max(base, CGFloat(count) * (minArc + gap) / sweep - thickness / 2)
    }

    private static func slices(_ entries: [WheelEntry], inner: CGFloat, thickness: CGFloat,
                               start: CGFloat, step: CGFloat) -> [(WheelEntry, WheelSector)] {
        entries.enumerated().map { index, entry in
            let a = start + CGFloat(index) * step
            return (entry, WheelSector(innerRadius: inner, outerRadius: inner + thickness, startAngle: a, endAngle: a + step))
        }
    }

    private static func formatEntries(_ formats: [FileFormat]) -> [WheelEntry] { formats.map { .action(.format($0)) } }
    private static func toolEntries(_ tools: [ToolKind]) -> [WheelEntry] { tools.map { .action(.tool($0)) } }

    /// One full ring of `entries`, the first slice centred at the top.
    private static func ring(_ entries: [WheelEntry], base: CGFloat, thickness: CGFloat) -> [(WheelEntry, WheelSector)] {
        guard !entries.isEmpty else { return [] }
        let step = tau / CGFloat(entries.count)
        let inner = pushedInnerRadius(count: entries.count, base: base, thickness: thickness, sweep: tau)
        return slices(entries, inner: inner, thickness: thickness, start: -step / 2, step: step)
    }

    private static func twoRings(formats: [FileFormat], tools: [ToolKind]) -> [(WheelEntry, WheelSector)] {
        let toolSlices = ring(toolEntries(tools), base: firstInnerRadius, thickness: toolRingThickness)
        let toolsOuter = toolSlices.first?.1.outerRadius
        let formatBase = toolsOuter.map { $0 + gap } ?? firstInnerRadius
        return ring(formatEntries(formats), base: formatBase, thickness: ringThickness) + toolSlices
    }

    private static func splitRing(formats: [FileFormat], tools: [ToolKind]) -> [(WheelEntry, WheelSector)] {
        let f = formats.count, t = tools.count
        let both = f > 0 && t > 0
        let slots = f + t + (both ? 2 : 0)
        guard slots > 0 else { return [] }
        let step = tau / CGFloat(slots)
        let inner = pushedInnerRadius(count: slots, base: firstInnerRadius, thickness: ringThickness, sweep: tau)
        let formatStart: CGFloat = both ? -CGFloat(f) * step / 2 : -step / 2
        let formatsEnd = formatStart + CGFloat(f) * step
        let toolStart = both ? formatsEnd + step : -step / 2
        return slices(formatEntries(formats), inner: inner, thickness: ringThickness, start: formatStart, step: step)
            + slices(toolEntries(tools), inner: inner, thickness: ringThickness, start: toolStart, step: step)
    }

    private static func twoSteps(step: WheelStep, formats: [FileFormat], tools: [ToolKind]) -> [(WheelEntry, WheelSector)] {
        switch step {
        case .root:
            let hasF = !formats.isEmpty, hasT = !tools.isEmpty
            if hasF && hasT {
                func half(_ start: CGFloat) -> WheelSector {
                    WheelSector(innerRadius: firstInnerRadius, outerRadius: firstInnerRadius + ringThickness,
                                startAngle: start, endAngle: start + .pi)
                }
                return [(.category(.convert), half(-.pi)), (.category(.tools), half(0))]
            }
            if hasF { return ring(formatEntries(formats), base: firstInnerRadius, thickness: ringThickness) }
            return ring(toolEntries(tools), base: firstInnerRadius, thickness: ringThickness)
        case .category(.convert):
            return ring(formatEntries(formats), base: firstInnerRadius, thickness: ringThickness)
        case .category(.tools):
            return ring(toolEntries(tools), base: firstInnerRadius, thickness: ringThickness)
        }
    }
}

/// Arrow-key navigation between wheel items.
enum WheelNavigator {
    /// The item to move to when an arrow key is pressed, or nil to stay where we are.
    /// Without a (valid) selection the topmost item is chosen.
    static func next(from index: Int?, direction: PickerMove, items: [WheelItem]) -> Int? {
        guard !items.isEmpty else { return nil }
        guard let index, items.indices.contains(index) else {
            return items.indices.min { a, b in
                let pa = items[a].offset, pb = items[b].offset
                return abs(pa.y - pb.y) > 0.5 ? pa.y < pb.y : abs(pa.x) < abs(pb.x)
            }
        }
        let vector: CGPoint
        switch direction {
        case .left: vector = CGPoint(x: -1, y: 0)
        case .right: vector = CGPoint(x: 1, y: 0)
        case .up: vector = CGPoint(x: 0, y: -1)
        case .down: vector = CGPoint(x: 0, y: 1)
        }
        let from = items[index].offset
        var best: (index: Int, score: CGFloat)?
        for (j, item) in items.enumerated() where j != index {
            let dx = item.offset.x - from.x, dy = item.offset.y - from.y
            let distance = hypot(dx, dy)
            guard distance > 0 else { continue }
            let cosine = (dx * vector.x + dy * vector.y) / distance
            guard cosine > 0.5 + 1e-6 else { continue }                // within 60° of the arrow (tolerance avoids float-noise ties)
            let score = distance * (1.5 - cosine)                       // near wins; straight ahead breaks near-ties
            if best == nil || score < best!.score { best = (j, score) }
        }
        return best?.index
    }
}
