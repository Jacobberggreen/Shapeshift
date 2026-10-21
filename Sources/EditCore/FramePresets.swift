import Foundation

/// A named frame style. Built-in presets are fixed; user presets can be renamed or deleted.
public struct FramePreset: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var style: FrameStyle
    public var isBuiltIn: Bool
    public init(id: String, name: String, style: FrameStyle, isBuiltIn: Bool) {
        self.id = id; self.name = name; self.style = style; self.isBuiltIn = isBuiltIn
    }
}

/// Stores user frame presets and the default choice in UserDefaults.
public final class FramePresetStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let userKey = "framePresets"
    private let defaultKey = "defaultFramePreset"

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    /// The presets shipped with the app: Clean card, Window and Floating.
    public static let builtIns: [FramePreset] = {
        var clean = FrameStyle()
        clean.cornerRadius = 16
        clean.shadowEnabled = true; clean.shadowOffsetY = 8; clean.shadowBlur = 24; clean.shadowOpacity = 0.25

        var window = FrameStyle()
        window.cornerRadius = 10; window.windowChrome = true
        window.borderWidth = 1; window.borderColor = RGBAColor(r: 0, g: 0, b: 0, a: 0.15)
        window.shadowEnabled = true; window.shadowOffsetY = 10; window.shadowBlur = 30; window.shadowOpacity = 0.35

        var floating = FrameStyle()
        floating.cornerRadius = 24; floating.margin = 48
        floating.shadowEnabled = true; floating.shadowOffsetY = 24; floating.shadowBlur = 48; floating.shadowOpacity = 0.45

        return [
            FramePreset(id: "builtin.clean", name: "Clean card", style: clean, isBuiltIn: true),
            FramePreset(id: "builtin.window", name: "Window", style: window, isBuiltIn: true),
            FramePreset(id: "builtin.floating", name: "Floating", style: floating, isBuiltIn: true),
        ]
    }()

    /// Presets the user created, stored as JSON in UserDefaults.
    public var userPresets: [FramePreset] {
        get {
            guard let data = defaults.data(forKey: userKey),
                  let presets = try? JSONDecoder().decode([FramePreset].self, from: data) else { return [] }
            return presets
        }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: userKey) }
    }

    /// Built-in presets followed by user presets.
    public var all: [FramePreset] { Self.builtIns + userPresets }

    /// The preset with this ID, or nil.
    public func preset(id: String) -> FramePreset? { all.first { $0.id == id } }

    /// ID of the default preset, falling back to Clean card when unset or missing.
    public var defaultPresetID: String {
        let stored = defaults.string(forKey: defaultKey)
        if let stored, preset(id: stored) != nil { return stored }
        return "builtin.clean"
    }

    /// The default preset itself.
    public var defaultPreset: FramePreset { preset(id: defaultPresetID) ?? Self.builtIns[0] }

    /// Creates and saves a user preset; a blank name becomes "Untitled".
    @discardableResult
    public func add(name: String, style: FrameStyle) -> FramePreset {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let preset = FramePreset(id: "user.\(UUID().uuidString)", name: trimmed.isEmpty ? "Untitled" : trimmed,
                                 style: style, isBuiltIn: false)
        userPresets.append(preset)
        return preset
    }

    /// Renames a user preset. Ignores blank names and IDs that are not user presets.
    public func rename(id: String, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var presets = userPresets
        guard let index = presets.firstIndex(where: { $0.id == id }) else { return }
        presets[index].name = trimmed
        userPresets = presets
    }

    /// Deletes a user preset and clears the default if it pointed to it. Built-in presets are kept.
    public func delete(id: String) {
        var presets = userPresets
        guard presets.contains(where: { $0.id == id }) else { return }
        presets.removeAll { $0.id == id }
        userPresets = presets
        if defaults.string(forKey: defaultKey) == id { defaults.removeObject(forKey: defaultKey) }
    }

    /// Makes `id` the default preset; ignored for unknown IDs.
    public func setDefault(id: String) {
        guard preset(id: id) != nil else { return }
        defaults.set(id, forKey: defaultKey)
    }
}
