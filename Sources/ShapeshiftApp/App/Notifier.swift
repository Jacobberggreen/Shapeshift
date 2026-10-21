import AppKit
import UserNotifications

/// Posts user notifications, with a file to reveal when clicked.
@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    private var available: Bool { Bundle.main.bundleIdentifier != nil }

    func setUp() {
        guard available else { return }
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert]) { _, _ in }
    }

    func post(title: String, body: String, reveal: URL?) {
        guard available else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if let reveal { content.userInfo = ["path": reveal.path] }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        if let path = response.notification.request.content.userInfo["path"] as? String {
            DispatchQueue.main.async {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
            }
        }
        completionHandler()
    }
}
