import Foundation
import Observation
import ServiceManagement

enum LoginItemStatus: Equatable, Sendable {
    case disabled
    case enabled
    case requiresApproval
    case unavailable

    var isRegistered: Bool {
        self == .enabled || self == .requiresApproval
    }
}

protocol LoginItemControlling: AnyObject {
    var status: LoginItemStatus { get }
    func register() throws
    func unregister(completion: @escaping @Sendable (String?) -> Void)
}

final class SystemLoginItemController: LoginItemControlling {
    private let service: SMAppService

    init(service: SMAppService = .mainApp) {
        self.service = service
    }

    var status: LoginItemStatus {
        switch service.status {
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notRegistered:
            return .disabled
        case .notFound:
            return .unavailable
        @unknown default:
            return .unavailable
        }
    }

    func register() throws {
        try service.register()
    }

    func unregister(completion: @escaping @Sendable (String?) -> Void) {
        service.unregister { error in
            completion(error?.localizedDescription)
        }
    }
}

@MainActor
@Observable
final class LoginItemManager {
    private let controller: any LoginItemControlling

    private(set) var status: LoginItemStatus
    private(set) var isChanging = false
    var errorMessage: String?

    init(controller: (any LoginItemControlling)? = nil) {
        let resolvedController = controller ?? SystemLoginItemController()
        self.controller = resolvedController
        status = resolvedController.status
    }

    func refresh() {
        status = controller.status
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled != status.isRegistered, !isChanging else { return }

        isChanging = true
        errorMessage = nil

        if enabled {
            do {
                try controller.register()
                isChanging = false
                refresh()
            } catch {
                isChanging = false
                errorMessage = error.localizedDescription
                refresh()
            }
        } else {
            controller.unregister { [weak self] errorMessage in
                Task { @MainActor in
                    guard let self else { return }
                    self.isChanging = false
                    self.errorMessage = errorMessage
                    self.refresh()
                }
            }
        }
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
