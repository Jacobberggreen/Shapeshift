import AppKit

/// Polls the drag pasteboard while the mouse is down and reports file drags with their intent.
@MainActor
final class DragMonitor {
    var onFileDrag: (([URL], NSPoint, DragIntent) -> Void)?
    var onDragEnded: (() -> Void)?

    private let settings: SettingsStore
    private var timer: Timer?
    private var wasDown = false
    private var changeCountAtMouseDown = 0
    private var active = false

    init(settings: SettingsStore) { self.settings = settings }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let pasteboard = NSPasteboard(name: .drag)
        let down = NSEvent.pressedMouseButtons & 1 != 0

        // Keep the baseline fresh while idle so a very fast drag cannot slip between ticks.
        if !down { changeCountAtMouseDown = pasteboard.changeCount }
        if down && !wasDown { changeCountAtMouseDown = pasteboard.changeCount }

        if down, pasteboard.changeCount != changeCountAtMouseDown {
            let urls = (pasteboard.readObjects(forClasses: [NSURL.self],
                                               options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
            let intent = DragIntent.resolve(flags: NSEvent.modifierFlags, triggers: settings.triggers)
            if !urls.isEmpty, let intent {
                active = true
                onFileDrag?(urls, NSEvent.mouseLocation, intent)
            } else if active {
                active = false
                onDragEnded?()
            }
        } else if active {
            active = false
            onDragEnded?()
        }
        wasDown = down
    }
}
