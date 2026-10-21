import AppKit

/// App delegate that creates the controller and registers the Finder service.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: AppController?
    private let serviceProvider = ServiceProvider()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = AppController()
        self.controller = controller
        serviceProvider.onFiles = { [weak controller] urls in controller?.showFinderPicker(urls: urls) }
        NSApp.servicesProvider = serviceProvider
        NSUpdateDynamicServices()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let controller, controller.hasRunningJobs else { return .terminateNow }
        Task { @MainActor in
            await controller.cancelAllJobs()
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}

@MainActor
public func runApp() {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    withExtendedLifetime(delegate) { app.run() }
}
