import ServiceManagement

/// The system login-item API, abstracted so tests can use a fake.
protocol LoginItemService {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

extension SMAppService: LoginItemService {}

/// Start-at-login state, always read from the system (nothing is cached or stored in UserDefaults).
struct LaunchAtLogin {
    static let approvalHint = "Approve Shapeshift in System Settings \u{203A} General \u{203A} Login Items"

    private let service: LoginItemService
    private(set) var lastError: String?

    init(service: LoginItemService = SMAppService.mainApp) {
        self.service = service
    }

    var isEnabled: Bool { service.status == .enabled || service.status == .requiresApproval }
    var needsApproval: Bool { service.status == .requiresApproval }

    /// Hint when approval is pending, the last failure otherwise, nil when all is well.
    var message: String? {
        if let lastError { return lastError }
        return needsApproval ? Self.approvalHint : nil
    }

    mutating func set(_ enabled: Bool) throws {
        lastError = nil
        do {
            if enabled {
                if service.status != .enabled { try service.register() }
            } else if service.status != .notRegistered {
                try service.unregister()
            }
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    static func openLoginItemsSettings() { SMAppService.openSystemSettingsLoginItems() }
}
