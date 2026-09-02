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

    var isEnabled: Bool {
        self == .enabled
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

    @ObservationIgnored
    private let systemSettingsOpener: @MainActor @Sendable () -> Void

    private(set) var status: LoginItemStatus
    private(set) var isChanging = false
    var errorMessage: String?

    init(
        controller: (any LoginItemControlling)? = nil,
        systemSettingsOpener: @escaping @MainActor @Sendable () -> Void = {
            SMAppService.openSystemSettingsLoginItems()
        }
    ) {
        let resolvedController = controller ?? SystemLoginItemController()
        self.controller = resolvedController
        self.systemSettingsOpener = systemSettingsOpener
        status = resolvedController.status
    }

    func refresh() {
        status = controller.status
    }

    func setEnabled(_ enabled: Bool) {
        guard !isChanging else { return }

        if enabled, status == .requiresApproval {
            systemSettingsOpener()
            return
        }

        if enabled {
            guard status != .enabled else { return }
        } else {
            guard status.isRegistered else { return }
        }

        isChanging = true
        errorMessage = nil

        if enabled {
            do {
                try controller.register()
                isChanging = false
                refresh()
                if status == .requiresApproval {
                    systemSettingsOpener()
                }
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
        systemSettingsOpener()
    }
}
