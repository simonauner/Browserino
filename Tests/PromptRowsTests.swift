import AppKit
import Foundation
import Testing

/// What the picker lists for a link, worked out from the stored settings.
struct PromptRowsTests {
    @Test("a domain mapped to a hidden profile still gets its row")
    func hiddenMappingShows() throws {
        let suiteName = "LotsenPromptRows-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let safari = try #require(NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari"))
        let plain = BrowserTarget(app: safari)
        let work = BrowserTarget(app: safari, profile: "Work")
        let settings = AppSettings(defaults: defaults)
        settings.browsers = [plain, work]
        settings.hiddenBrowsers = [work]
        settings.apps = [
            App(host: "jira.example.com", schemeOverride: "", app: safari, profile: "Work"),
            App(host: "jira.example.com", schemeOverride: "", app: safari),
        ]

        let rows = PromptRows(urls: [try #require(URL(string: "https://jira.example.com/a"))], sourceTab: nil, settings: settings, defaults: defaults)

        #expect(rows.browsers.map(\.target) == [plain], "the hidden profile stays out of the browser list")
        #expect(rows.apps.map(\.target) == [work], "its mapping is listed, while one to a listed browser is not repeated")
    }
}
