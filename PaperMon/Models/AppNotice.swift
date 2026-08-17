import Foundation

struct AppNotice: Identifiable, Sendable {
    let id = UUID()
    var title: String
    var message: String
}

enum ApplicationStatus: Equatable, Sendable {
    case idle
    case applying
    case applied(String)
    case needsAttention(String)

    var label: String? {
        switch self {
        case .idle, .applying:
            nil
        case let .applied(message), let .needsAttention(message):
            message
        }
    }
}

