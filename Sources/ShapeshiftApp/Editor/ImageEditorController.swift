import AppKit
import SwiftUI
import EditCore

/// Owns the editor window for a set of images and hands the plan back on Save.
@MainActor
final class ImageEditorController: NSObject, NSWindowDelegate {
    private let model: EditorModel
    private let urls: [URL]
    private let transparencyPreview: TransparencyPreview
    private let onSave: (EditorPlan, [URL]) -> Void
    private var window: NSWindow?
    var onClose: (() -> Void)?

    init(urls: [URL], initialTool: EditTool, presets: FramePresetStore, baseQuality: Double,
         transparencyPreview: TransparencyPreview = .frosted,
         onSave: @escaping (EditorPlan, [URL]) -> Void) {
        self.urls = urls
        self.transparencyPreview = transparencyPreview
        self.onSave = onSave
        self.model = EditorModel(urls: urls, initialTool: initialTool, presets: presets, baseQuality: baseQuality)
        super.init()
    }

    func show() {
        let view = EditorView(model: model,
                              onSave: { [weak self] plan in
                                  guard let self else { return }
                                  self.onSave(plan, self.urls)
                                  self.close()
                              },
                              onCancel: { [weak self] in self?.close() },
                              transparencyPreview: transparencyPreview)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 620),
                              styleMask: [.titled, .closable, .resizable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.title = urls.count == 1 ? urls[0].lastPathComponent : "Edit \(urls.count) images"
        window.isReleasedWhenClosed = false
        window.delegate = self
        GlassWindow.install(view, in: window, size: NSSize(width: 900, height: 620))
        let titleInset = window.frame.height - window.contentLayoutRect.height
        window.contentMinSize = NSSize(width: 760, height: 520 + titleInset)
        window.center()
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func close() { window?.close() }

    func windowWillClose(_ notification: Notification) {
        window?.delegate = nil
        window = nil
        let callback = onClose
        onClose = nil   // drop the owner's closure so nothing keeps the controller alive after close
        callback?()
    }
}
