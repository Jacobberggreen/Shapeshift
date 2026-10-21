import XCTest
import ServiceManagement
@testable import ShapeshiftApp

final class LaunchAtLoginTests: XCTestCase {
    private struct Boom: LocalizedError { var errorDescription: String? { "boom" } }

    private final class FakeService: LoginItemService {
        var status: SMAppService.Status = .notRegistered
        var registerResult: SMAppService.Status = .enabled
        var failure: Error?
        func register() throws {
            if let failure { throw failure }
            status = registerResult
        }
        func unregister() throws { status = .notRegistered }
    }

    func testEnable() throws {
        let fake = FakeService()
        var login = LaunchAtLogin(service: fake)
        XCTAssertFalse(login.isEnabled)
        try login.set(true)
        XCTAssertTrue(login.isEnabled)
        XCTAssertFalse(login.needsApproval)
        XCTAssertNil(login.message)
    }

    func testDisable() throws {
        let fake = FakeService()
        fake.status = .enabled
        var login = LaunchAtLogin(service: fake)
        try login.set(false)
        XCTAssertFalse(login.isEnabled)
        XCTAssertNil(login.message)
    }

    func testRequiresApprovalCountsAsEnabledWithHint() throws {
        let fake = FakeService()
        fake.registerResult = .requiresApproval
        var login = LaunchAtLogin(service: fake)
        try login.set(true)
        XCTAssertTrue(login.isEnabled)
        XCTAssertTrue(login.needsApproval)
        XCTAssertEqual(login.message, LaunchAtLogin.approvalHint)
    }

    func testRegisterFailureSurfacesErrorText() {
        let fake = FakeService()
        fake.failure = Boom()
        var login = LaunchAtLogin(service: fake)
        XCTAssertThrowsError(try login.set(true))
        XCTAssertFalse(login.isEnabled)
        XCTAssertEqual(login.message, "boom")
    }

    func testErrorClearsOnNextSuccess() throws {
        let fake = FakeService()
        fake.failure = Boom()
        var login = LaunchAtLogin(service: fake)
        XCTAssertThrowsError(try login.set(true))
        fake.failure = nil
        try login.set(true)
        XCTAssertNil(login.message)
    }
}
