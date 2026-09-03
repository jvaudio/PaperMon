import Testing
@testable import PaperMon

@Suite("AppVersionInfoTests")
struct AppVersionInfoTests {
    @Test
    func formatsMarketingVersionAndBuildNumber() {
        let version = AppVersionInfo(infoDictionary: [
            "CFBundleShortVersionString": "1.2.3",
            "CFBundleVersion": "42",
        ])

        #expect(version.displayValue == "1.2.3 (42)")
    }

    @Test
    func usesFallbacksWhenBundleMetadataIsMissing() {
        let version = AppVersionInfo(infoDictionary: [:])

        #expect(version.displayValue == "Unknown (Unknown)")
    }
}
