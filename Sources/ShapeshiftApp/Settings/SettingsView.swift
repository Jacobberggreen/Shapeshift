import SwiftUI
import AppKit
import CoreGraphics
import ServiceManagement

/// Settings window: triggers, menu style, quality and start at login.
struct SettingsView: View {
    let settings: SettingsStore
    let ffmpegPath: String?

    @State private var quality: Double
    @State private var convert: TriggerModifiers
    @State private var tools: TriggerModifiers
    @State private var transparency: TransparencyPreview
    @State private var menuStyle: MenuStyle
    @State private var glassStyle: GlassStyle
    @State private var selectionMode: SelectionColorMode
    @State private var selectionColor: Color
    @State private var inputMonitoringGranted = CGPreflightListenEventAccess()
    @State private var launchAtLogin = LaunchAtLogin()
    @State private var launchAtLoginOn = false

    init(settings: SettingsStore, ffmpegPath: String?) {
        self.settings = settings
        self.ffmpegPath = ffmpegPath
        _quality = State(initialValue: settings.quality)
        _convert = State(initialValue: settings.triggers.convert)
        _tools = State(initialValue: settings.triggers.tools)
        _transparency = State(initialValue: settings.transparencyPreview)
        _menuStyle = State(initialValue: settings.menuStyle)
        _glassStyle = State(initialValue: settings.glassStyle)
        _selectionMode = State(initialValue: settings.selectionColorMode)
        _selectionColor = State(initialValue: Color(nsColor: SelectionStyle.parseHex(settings.selectionColorHex)
            ?? SelectionStyle.parseHex(SettingsStore.defaultSelectionHex)!))
    }

    private var defaultQualityPercent: Int { Int((SettingsStore.defaultQuality * 100).rounded()) }
    private var valid: Bool { TriggerConfig(convert: convert, tools: tools).isValid }

    var body: some View {
        TabView {
            generalTab.tabItem { Label("General", systemImage: "gearshape") }
            appearanceTab.tabItem { Label("Appearance", systemImage: "paintbrush") }
            finderTab.tabItem { Label("Finder & keys", systemImage: "folder") }
            toolsTab.tabItem { Label("Tools", systemImage: "wrench.and.screwdriver") }
        }
        .frame(minWidth: 520, minHeight: 380)
        .onAppear {
            inputMonitoringGranted = CGPreflightListenEventAccess()
            refreshLaunchAtLogin()
        }
        .onChange(of: quality) { settings.quality = $0 }
        .onChange(of: convert) { _ in save() }
        .onChange(of: tools) { _ in save() }
        .onChange(of: transparency) { settings.transparencyPreview = $0 }
        .onChange(of: menuStyle) { settings.menuStyle = $0 }
        .onChange(of: glassStyle) { settings.glassStyle = $0 }
        .onChange(of: selectionMode) { settings.selectionColorMode = $0 }
        .onChange(of: selectionColor) { settings.selectionColorHex = SelectionStyle.hex(of: NSColor($0)) }
    }

    private var generalTab: some View {
        Form {
            Section("Startup") {
                Toggle("Start Shapeshift at login", isOn: Binding(
                    get: { launchAtLoginOn },
                    set: { setLaunchAtLogin($0) }))
                if let message = launchAtLogin.message {
                    Text(message).font(.caption)
                        .foregroundStyle(launchAtLogin.needsApproval ? Color.secondary : Color.red)
                }
                if launchAtLogin.needsApproval {
                    Button("Open Login Items settings") { LaunchAtLogin.openLoginItemsSettings() }
                }
            }
            Section("Trigger keys (hold while dragging a file)") {
                ModifierRow(title: "Convert", value: $convert)
                ModifierRow(title: "Tools", value: $tools)
                if !valid {
                    Text("Each trigger needs at least one key, and the two must differ. Changes are not saved until valid.")
                        .font(.caption).foregroundStyle(.red)
                }
            }
            Section("Quality") {
                Slider(value: $quality, in: 0...1) { Text("Default quality") }
                Text("\(Int(quality * 100))%").font(.caption).foregroundStyle(.secondary)
                Text("Used for lossy output \u{2014} JPEG, HEIC, WebP, compressed audio and video. Default \(defaultQualityPercent) %.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Reset to \(defaultQualityPercent) %") { quality = SettingsStore.defaultQuality }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private var appearanceTab: some View {
        Form {
            Section("Appearance") {
                Picker("Menu style", selection: $menuStyle) {
                    ForEach(MenuStyle.allCases) { Text($0.title).tag($0) }
                }
                Text(menuStyle.summary).font(.caption).foregroundStyle(.secondary)
                if #available(macOS 26.0, *) {
                    Picker("Glass style", selection: $glassStyle) {
                        ForEach(GlassStyle.allCases) { Text($0.title).tag($0) }
                    }
                    Text("Applies to the wheel, editor and other glass surfaces. Frosted uses a plain blurred material.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Picker("Selected slice colour", selection: $selectionMode) {
                    ForEach(SelectionColorMode.allCases) { Text($0.title).tag($0) }
                }
                if selectionMode == .custom {
                    ColorPicker("Custom colour", selection: $selectionColor, supportsOpacity: false)
                }
                Text("The colour of the highlighted slice in the wheel. Lighter and Darker are soft neutral tones (no colour).")
                    .font(.caption).foregroundStyle(.secondary)
                Picker("Transparent image preview", selection: $transparency) {
                    ForEach(TransparencyPreview.allCases) { Text($0.title).tag($0) }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private var finderTab: some View {
        Form {
            Section("Finder") {
                Text("Right-click files → Shapeshift… (at the bottom of the menu, or under Services). The entry appears after Shapeshift has been launched once.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Refresh services") { NSUpdateDynamicServices() }
                    Button("Open Keyboard Shortcuts…") { openServicesSettings() }
                }
                Text("If the entry is missing: System Settings › Keyboard › Keyboard Shortcuts › Services › Files and Folders › Shapeshift.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Keyboard selection (arrows / Return / Esc)") {
                Text(inputMonitoringGranted
                     ? "Input Monitoring: granted"
                     : "Input Monitoring: not granted — arrow keys, Return and Esc will do nothing while dragging")
                    .font(.caption)
                    .foregroundStyle(inputMonitoringGranted ? Color.secondary : Color.red)
                Text("Dragging and dropping onto a format works without this permission.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Grant access…") { requestInputMonitoring() }
                Text("If keys still do nothing, also allow Shapeshift under Accessibility.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private var toolsTab: some View {
        Form {
            Section("About") {
                Text("Shapeshift \(Self.versionString)").font(.caption).foregroundStyle(.secondary)
            }
            Section("Tools") {
                if let ffmpegPath {
                    Text("ffmpeg: \(ffmpegPath)").font(.caption)
                } else {
                    Text("ffmpeg not found. Install with `brew install ffmpeg`, then relaunch Shapeshift.").font(.caption).foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private func refreshLaunchAtLogin() {
        launchAtLogin = LaunchAtLogin()
        launchAtLoginOn = launchAtLogin.isEnabled
    }

    private func setLaunchAtLogin(_ on: Bool) {
        var login = LaunchAtLogin()
        try? login.set(on)
        launchAtLogin = login
        launchAtLoginOn = login.isEnabled
    }

    static var versionString: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "dev"
    }

    private func requestInputMonitoring() {
        _ = CGRequestListenEventAccess()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
        inputMonitoringGranted = CGPreflightListenEventAccess()
    }

    private func openServicesSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    private func save() {
        settings.triggers = TriggerConfig(convert: convert, tools: tools)
    }

    private struct ModifierRow: View {
        let title: String
        @Binding var value: TriggerModifiers

        var body: some View {
            HStack {
                Text(title)
                Spacer()
                toggle("⇧", .shift)
                toggle("⌥", .option)
                toggle("⌃", .control)
                toggle("⌘", .command)
            }
        }

        private func toggle(_ label: String, _ flag: TriggerModifiers) -> some View {
            Toggle(label, isOn: Binding(
                get: { value.contains(flag) },
                set: { on in if on { value.insert(flag) } else { value.remove(flag) } }))
                .toggleStyle(.button)
        }
    }
}
