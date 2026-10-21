import AppKit
import SwiftUI

/// Work a PDF tool hands to the app: runs off the main thread and returns the files it wrote.
typealias PDFJob = @Sendable () throws -> [URL]

/// Owns the window for one PDF tool and hands its job to the app.
@MainActor
final class PDFToolController: NSObject, NSWindowDelegate {
    private let urls: [URL]
    private let tool: PDFTool
    private let runJob: (@escaping PDFJob) -> Void
    private var window: NSWindow?
    var onClose: (() -> Void)?

    init(urls: [URL], tool: PDFTool, runJob: @escaping (@escaping PDFJob) -> Void) {
        self.urls = urls
        self.tool = tool
        self.runJob = runJob
        super.init()
    }

    func show() {
        let view = PDFToolRootView(tool: tool, urls: urls,
                                   runJob: { [weak self] job in
                                       self?.runJob(job)
                                       self?.close()
                                   },
                                   onCancel: { [weak self] in self?.close() })
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 640),
                              styleMask: [.titled, .closable, .resizable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.title = "PDF — \(tool.title)"
        window.isReleasedWhenClosed = false
        window.delegate = self
        GlassWindow.install(view, in: window, size: NSSize(width: 900, height: 640))
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
        onClose = nil
        callback?()
    }
}
