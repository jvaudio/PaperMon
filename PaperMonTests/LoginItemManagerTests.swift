import Foundation
import Testing

@testable import PaperMon

@MainActor
struct LoginItemManagerTests {
    @Test func enablingRegistersAndRefreshesStatus() {
        let controller = FakeLoginItemController(status: .disabled)
        let manager = LoginItemManager(controller: controller)

        manager.setEnabled(true)

        #expect(controller.registerCallCount == 1)
        #expect(manager.status == .enabled)
        #expect(!manager.isChanging)
        #expect(manager.errorMessage == nil)
    }

    @Test func approvalStateRemainsVisiblyRegistered() async {
        let controller = FakeLoginItemController(status: .requiresApproval)
        let manager = LoginItemManager(controller: controller)

        #expect(manager.status.isRegistered)

        manager.setEnabled(false)
        await Task.yield()

        #expect(controller.unregisterCallCount == 1)
        #expect(manager.status == .disabled)
    }

    @Test func registrationFailureIsReported() {
        let controller = FakeLoginItemController(status: .disabled)
        controller.registrationError = TestError.registrationFailed
        let manager = LoginItemManager(controller: controller)

        manager.setEnabled(true)

        #expect(manager.status == .disabled)
        #expect(manager.errorMessage != nil)
        #expect(!manager.isChanging)
    }
}

private final class FakeLoginItemController: LoginItemControlling, @unchecked Sendable {
    var status: LoginItemStatus
    var registrationError: Error?
    private(set) var registerCallCount = 0
    private(set) var unregisterCallCount = 0

    init(status: LoginItemStatus) {
        self.status = status
    }

    func register() throws {
        registerCallCount += 1
        if let registrationError {
            throw registrationError
        }
        status = .enabled
    }

    func unregister(completion: @escaping @Sendable (String?) -> Void) {
        unregisterCallCount += 1
        status = .disabled
        completion(nil)
    }
}

private enum TestError: LocalizedError {
    case registrationFailed

    var errorDescription: String? {
        "Registration failed"
    }
}
