import AppKit
import SwiftUI

/// Sets up an NSWindow with a frosted background and a transparent title bar for SwiftUI content.
@MainActor
enum GlassWindow {
    /// Content view = behind-window blur (the frosted window background) with the SwiftUI view pinned inside.
    /// Transparent title bar, content running under it (SwiftUI's safe area keeps controls clear of the traffic lights).
    static func install<V: View>(_ rootView: V, in window: NSWindow, size: NSSize? = nil) {
        let hosting = NSHostingView(rootView: rootView)
        let effect = NSVisualEffectView()
        effect.material = .underWindowBackground
        effect.blendingMode = .behindWindow
        effect.state = .active
        hosting.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: effect.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
        ])
        window.contentView = effect

        window.styleMask.insert(.fullSizeContentView)
        window.titlebarAppearsTransparent = true
        if let size {
            window.setContentSize(size)
        } else {
            // The content runs under the title bar, so its safe-area inset adds to the fitting height.
            let inset = window.frame.height - window.contentLayoutRect.height
            let fitting = hosting.fittingSize
            window.setContentSize(NSSize(width: fitting.width, height: fitting.height + inset))
        }
    }
}
