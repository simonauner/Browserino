import Foundation
import Testing

struct PrivateBrowsingPolicyTests {
    @Test("Firefox private-window flags consume one URL; Chromium flags cover the batch")
    func privateBatches() throws {
        let firefox = try #require(PrivateBrowsingPolicy.argument(for: "org.mozilla.firefox", overrides: [:]))
        let chrome = try #require(PrivateBrowsingPolicy.argument(for: "com.google.Chrome", overrides: [:]))
        #expect(!PrivateBrowsingPolicy.acceptsMultipleURLs(argument: firefox))
        #expect(!PrivateBrowsingPolicy.acceptsMultipleURLs(argument: "-private-window"))
        #expect(PrivateBrowsingPolicy.acceptsMultipleURLs(argument: chrome))
    }
    @Test("known browsers have private defaults and explicit overrides take precedence")
    func arguments() {
        #expect(PrivateBrowsingPolicy.argument(for: "com.google.Chrome", overrides: [:]) == "--incognito")
        #expect(PrivateBrowsingPolicy.argument(for: "com.brave.Browser.beta", overrides: [:]) == "--incognito")
        #expect(PrivateBrowsingPolicy.argument(for: "com.microsoft.edgemac", overrides: [:]) == "--inprivate")
        #expect(PrivateBrowsingPolicy.argument(for: "org.mozilla.firefox", overrides: [:]) == "--private-window")
        #expect(PrivateBrowsingPolicy.argument(for: "com.apple.Safari", overrides: [:]) == nil)
        #expect(PrivateBrowsingPolicy.argument(for: "com.google.Chrome", overrides: ["com.google.Chrome": ""]) == nil)
        #expect(PrivateBrowsingPolicy.argument(for: "custom", overrides: ["custom": "--private"]) == "--private")
        #expect(PrivateBrowsingPolicy.argument(for: "com.google.ChromeImpostor", overrides: [:]) == nil)
    }

    @Test("private opening is available for plain app mappings, never for scheme overrides")
    func mappings() {
        #expect(PrivateBrowsingPolicy.canOpen(identifier: "org.mozilla.firefox", overrides: [:]))
        #expect(!PrivateBrowsingPolicy.canOpen(identifier: "org.mozilla.firefox", overrides: [:], schemeOverride: "figma"))
        #expect(!PrivateBrowsingPolicy.canOpen(identifier: nil, overrides: [:]))
    }
}

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
