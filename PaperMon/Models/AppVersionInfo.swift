import Foundation

struct AppVersionInfo: Equatable, Sendable {
    let marketingVersion: String
    let buildNumber: String

    init(infoDictionary: [String: Any] = Bundle.main.infoDictionary ?? [:]) {
        marketingVersion = infoDictionary["CFBundleShortVersionString"] as? String ?? "Unknown"
        buildNumber = infoDictionary["CFBundleVersion"] as? String ?? "Unknown"
    }

    var displayValue: String {
        "\(marketingVersion) (\(buildNumber))"
    }
}
