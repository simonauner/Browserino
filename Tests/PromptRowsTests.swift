import AppKit
import Foundation
import Testing

/// What the picker lists for a link, worked out from the stored settings.
struct PromptRowsTests {
    @Test("batch app choices must match every link and an empty batch has no apps")
    func batchMappings() throws {
        let suiteName = "LotsenBatchRows-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let safari = try #require(NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari"))
        let settings = AppSettings(defaults: defaults)
        settings.apps = [App(host: "example.com", schemeOverride: "custom", app: safari)]
        let first = try #require(URL(string: "https://example.com/a"))
        let sameDomain = try #require(URL(string: "https://sub.example.com/b"))
        let other = try #require(URL(string: "https://other.com/b"))
        func rows(_ urls: [URL]) -> PromptRows {
            PromptRows(urls: urls, sourceTab: nil, settings: settings, defaults: defaults)
        }
        #expect(rows([first, sameDomain]).apps.count == 1)
        #expect(rows([first, other]).apps.isEmpty)
        #expect(rows([]).apps.isEmpty)
        settings.apps = [App(host: "", schemeOverride: "", app: safari)]
        #expect(rows([first, other]).apps.count == 1, "an explicit all-domains mapping remains available")
    }
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
