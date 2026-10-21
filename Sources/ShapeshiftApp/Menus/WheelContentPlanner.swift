import ConversionCore
import EditCore

/// The formats and tools to show in the wheel for the current files.
struct WheelContent: Equatable {
    var formats: [FileFormat]
    var tools: [ToolKind]
}

/// Decides what a drag wheel shows for a style and trigger. Combined styles
/// show the same content for both triggers, so toggling Option mid-drag
/// does not rebuild the wheel.
enum WheelContentPlanner {
    static func plan(style: MenuStyle, intent: DragIntent, formats: [FileFormat], tools: [ToolKind]) -> WheelContent? {
        switch style {
        case .classicGrid:
            return nil
        case .twoRings, .splitRing:
            let content = WheelContent(formats: formats, tools: tools)
            return content.formats.isEmpty && content.tools.isEmpty ? nil : content
        case .twoSteps:
            switch intent {
            case .convert:
                return formats.isEmpty ? nil : WheelContent(formats: formats, tools: [])
            case .tools:
                return tools.isEmpty ? nil : WheelContent(formats: [], tools: tools)
            }
        }
    }
}
