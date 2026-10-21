import AppKit

/// What a file drag should do, chosen from the modifier keys held during the drag.
enum DragIntent: Equatable {
    case convert, tools

    static func resolve(flags: NSEvent.ModifierFlags, triggers: TriggerConfig) -> DragIntent? {
        if triggers.convert.matches(flags) { return .convert }
        if triggers.tools.matches(flags) { return .tools }
        return nil
    }
}
