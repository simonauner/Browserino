import Foundation
import Testing

struct LanguagePolicyTests {
    @Test("manual language")
    func manualLanguage() {
        #expect(LanguagePolicy.resolve(selection: "ru", preferred: ["de-DE"]) == "ru")
    }

    @Test("invalid selection falls back")
    func invalidSelectionFallsBack() {
        #expect(LanguagePolicy.resolve(selection: "invalid", preferred: ["de-DE"]) == "de")
    }

    @Test("system preferred order")
    func systemPreferredOrder() {
        #expect(LanguagePolicy.resolve(selection: "", preferred: ["uk", "fr-CA"]) == "fr")
    }

    @Test("English fallback")
    func englishFallback() {
        #expect(LanguagePolicy.resolve(selection: "", preferred: ["zz"]) == "en")
    }
}

struct ProfilePathPolicyTests {
    @Test("profile traversal rejected")
    func traversalRejected() {
        #expect(!ProfilePathPolicy.isSafeComponent("../Profile 1"))
    }

    @Test("absolute profile rejected")
    func absoluteRejected() {
        #expect(!ProfilePathPolicy.isSafeComponent("/tmp/x"))
    }

    @Test("valid profile name")
    func validName() {
        #expect(ProfilePathPolicy.isSafeComponent("Profile 1"))
    }

    @Test("symlink escape rejected, child allowed")
    func containment() throws {
        let fixture = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: fixture, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: fixture) }
        let root = fixture.appendingPathComponent("root")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let escaped = root.appendingPathComponent("avatar")
        try FileManager.default.createSymbolicLink(at: escaped, withDestinationURL: fixture)

        #expect(!ProfilePathPolicy.contains(escaped.appendingPathComponent("outside.png"), in: root), "symlink escape rejected")
        #expect(ProfilePathPolicy.contains(root.appendingPathComponent("Profile 1"), in: root), "child allowed")
    }
}
