import AppKit

/// Owns the status bar item and its menu.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let onSettings: () -> Void
    private let triggerSymbols: () -> String
    private let hint = NSMenuItem(title: "", action: nil, keyEquivalent: "")

    init(onSettings: @escaping () -> Void, ffmpegAvailable: Bool, triggerSymbols: @escaping () -> String) {
        self.onSettings = onSettings
        self.triggerSymbols = triggerSymbols
        super.init()
        item.button?.image = Self.menuBarImage()
        let menu = NSMenu()
        let about = NSMenuItem(title: "About Shapeshift", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        menu.addItem(.separator())
        hint.isEnabled = false
        menu.addItem(hint)
        if !ffmpegAvailable {
            let missing = NSMenuItem(title: "ffmpeg missing: run `brew install ffmpeg`, then relaunch", action: nil, keyEquivalent: "")
            missing.isEnabled = false
            menu.addItem(missing)
        }
        menu.delegate = self
        refreshHint()
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(NSMenuItem(title: "Quit Shapeshift", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) { refreshHint() }

    private func refreshHint() { hint.title = "Hold \(triggerSymbols()) while dragging a file" }

    /// Shows the number of running jobs next to the icon; empty when idle.
    func setBusy(_ count: Int) {
        item.button?.title = count > 0 ? " \(count)" : ""
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: NSAttributedString(string: "Local file converter and tools.\nConcept and wheel menu inspired by Tangerine (tangerineformac.com).")
        ])
    }

    @objc private func openSettings() { onSettings() }

    /// The S from the app icon as a template image (macOS tints it for light, dark and highlighted states).
    /// Falls back to a system symbol when the bundled PDF is missing (e.g. when run with `swift run`).
    private static func menuBarImage() -> NSImage? {
        if let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "pdf"), let image = NSImage(contentsOf: url) {
            let height: CGFloat = 15   // glyph height of typical status bar icons
            image.size = NSSize(width: height * image.size.width / max(image.size.height, 1), height: height)
            image.isTemplate = true
            image.accessibilityDescription = "Shapeshift"
            return image
        }
        return NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: "Shapeshift")
    }
}
