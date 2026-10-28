import Foundation
import Testing

/// Earlier builds stored browsers as bare URL strings, and those must still decode.
struct BrowserTargetTests {
    private let decoder = JSONDecoder()

    private func legacyTargets() throws -> [BrowserTarget] {
        try decoder.decode([BrowserTarget].self, from: Data(#"["file:///Applications/A.app/","file:///Applications/B.app/"]"#.utf8))
    }

    private func profileTargets() throws -> [BrowserTarget] {
        try decoder.decode([BrowserTarget].self, from: Data(#"[{"app":"file:///Applications/A.app/","profile":"Profile 1"}]"#.utf8))
    }

    @Test("legacy order survives")
    func legacyOrderSurvives() throws {
        #expect(try legacyTargets().map(\.app.lastPathComponent) == ["A.app", "B.app"])
    }

    @Test("legacy profiles are nil")
    func legacyProfilesAreNil() throws {
        #expect(try legacyTargets().allSatisfy { $0.profile == nil })
    }

    @Test("profile is decoded")
    func profileIsDecoded() throws {
        #expect(try profileTargets()[0].profile == "Profile 1")
    }

    @Test("legacy shortcut is unchanged")
    func legacyShortcutIsUnchanged() throws {
        #expect(try legacyTargets()[0].shortcutKey(bundleIdentifier: "test.app") == "test.app")
    }

    @Test("profile shortcut is distinct")
    func profileShortcutIsDistinct() throws {
        #expect(try profileTargets()[0].shortcutKey(bundleIdentifier: "test.app") == "test.app#Profile 1")
    }

    @Test("malformed targets rejected")
    func malformedTargetsRejected() {
        #expect((try? decoder.decode([BrowserTarget].self, from: Data("[42]".utf8))) == nil)
    }
}
