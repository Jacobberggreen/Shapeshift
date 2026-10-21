import AppKit

/// Set of modifier keys, stored as a bitmask, used to trigger drags.
public struct TriggerModifiers: OptionSet, Codable, Equatable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let shift = TriggerModifiers(rawValue: 1 << 0)
    public static let option = TriggerModifiers(rawValue: 1 << 1)
    public static let control = TriggerModifiers(rawValue: 1 << 2)
    public static let command = TriggerModifiers(rawValue: 1 << 3)

    public init(flags: NSEvent.ModifierFlags) {
        var result: TriggerModifiers = []
        if flags.contains(.shift) { result.insert(.shift) }
        if flags.contains(.option) { result.insert(.option) }
        if flags.contains(.control) { result.insert(.control) }
        if flags.contains(.command) { result.insert(.command) }
        self = result
    }

    public func matches(_ flags: NSEvent.ModifierFlags) -> Bool {
        TriggerModifiers(flags: flags) == self
    }

    public var symbols: String {
        var s = ""
        if contains(.control) { s += "⌃" }
        if contains(.option) { s += "⌥" }
        if contains(.shift) { s += "⇧" }
        if contains(.command) { s += "⌘" }
        return s
    }
}

/// Modifier combinations that start a convert drag and a tools drag.
public struct TriggerConfig: Codable, Equatable, Sendable {
    public var convert: TriggerModifiers
    public var tools: TriggerModifiers

    public init(convert: TriggerModifiers, tools: TriggerModifiers) {
        self.convert = convert
        self.tools = tools
    }

    public static let `default` = TriggerConfig(convert: .shift, tools: [.shift, .option])

    public var isValid: Bool { !convert.isEmpty && !tools.isEmpty && convert != tools }
}

/// Layout of the drag menu.
public enum MenuStyle: String, CaseIterable, Identifiable, Sendable {
    case twoRings, splitRing, twoSteps, classicGrid
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .twoRings: return "Two rings"
        case .splitRing: return "Split ring"
        case .twoSteps: return "Two steps"
        case .classicGrid: return "Classic grid"
        }
    }
    public var summary: String {
        switch self {
        case .twoRings: return "Formats in the outer ring, image tools in the inner ring. Both triggers show the same wheel."
        case .splitRing: return "One ring: formats, a gap, then image tools. Both triggers show the same wheel."
        case .twoSteps: return "The convert trigger shows formats, the tools trigger shows image tools. In Finder you first pick Convert or Tools."
        case .classicGrid: return "The original box: the convert trigger shows formats, the tools trigger shows image tools."
        }
    }
}

/// How transparent images are shown in the editor preview.
public enum TransparencyPreview: String, CaseIterable, Identifiable, Sendable {
    case frosted, checkerboard
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .frosted: return "Frosted glass"
        case .checkerboard: return "Checkerboard"
        }
    }
}

/// Glass look for app surfaces: Liquid Glass or frosted.
public enum GlassStyle: String, CaseIterable, Identifiable, Sendable {
    case liquid, frosted
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .liquid: return "Liquid Glass"
        case .frosted: return "Frosted"
        }
    }
}

/// How the highlighted slice's colour is derived: from the accent, lighter, darker or custom.
public enum SelectionColorMode: String, CaseIterable, Identifiable, Sendable {
    case accent, lighter, darker, custom
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .accent: return "System accent"
        case .lighter: return "Lighter"
        case .darker: return "Darker"
        case .custom: return "Custom colour"
        }
    }
}

/// Reads and writes the app's settings in UserDefaults as typed values.
public final class SettingsStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let triggersKey = "triggers"
    private let qualityKey = "quality"
    private let menuStyleKey = "menuStyle"
    private let transparencyKey = "transparencyPreview"

    public static let glassStyleKey = "glassStyle"
    public static let selectionColorModeKey = "selectionColorMode"
    public static let selectionColorHexKey = "selectionColorHex"
    public static let defaultSelectionHex = "#0A84FF"
    public static let defaultQuality = 0.85

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public var triggers: TriggerConfig {
        get {
            guard let data = defaults.data(forKey: triggersKey),
                  let config = try? JSONDecoder().decode(TriggerConfig.self, from: data),
                  config.isValid else { return .default }
            return config
        }
        set {
            guard newValue.isValid, let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: triggersKey)
        }
    }

    public var quality: Double {
        get { (defaults.object(forKey: qualityKey) as? Double) ?? Self.defaultQuality }
        set { defaults.set(min(max(newValue, 0), 1), forKey: qualityKey) }
    }

    public var menuStyle: MenuStyle {
        get { defaults.string(forKey: menuStyleKey).flatMap(MenuStyle.init(rawValue:)) ?? .twoRings }
        set { defaults.set(newValue.rawValue, forKey: menuStyleKey) }
    }

    public var transparencyPreview: TransparencyPreview {
        get { defaults.string(forKey: transparencyKey).flatMap(TransparencyPreview.init(rawValue:)) ?? .frosted }
        set { defaults.set(newValue.rawValue, forKey: transparencyKey) }
    }

    public var glassStyle: GlassStyle {
        get { defaults.string(forKey: Self.glassStyleKey).flatMap(GlassStyle.init(rawValue:)) ?? .liquid }
        set { defaults.set(newValue.rawValue, forKey: Self.glassStyleKey) }
    }

    public var selectionColorMode: SelectionColorMode {
        get { defaults.string(forKey: Self.selectionColorModeKey).flatMap(SelectionColorMode.init(rawValue:)) ?? .accent }
        set { defaults.set(newValue.rawValue, forKey: Self.selectionColorModeKey) }
    }

    public var selectionColorHex: String {
        get { defaults.string(forKey: Self.selectionColorHexKey) ?? Self.defaultSelectionHex }
        set { defaults.set(newValue, forKey: Self.selectionColorHexKey) }
    }
}
