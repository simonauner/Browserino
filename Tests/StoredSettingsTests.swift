import Foundation
import Testing

/// Existing settings and exported files depend on this exact storage format.
struct StoredSettingsTests {
    private let suiteName = "BrowserinoJSONDefaultsChecks-" + UUID().uuidString

    private func withDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try body(defaults)
    }

    @Test("settings keep their JSON string format and round-trip")
    func roundTrip() throws {
        try withDefaults { defaults in
            defaults.setJSON(["com.google.Chrome": "C"], forKey: "shortcuts")
            #expect(defaults.string(forKey: "shortcuts") == #"{"com.google.Chrome":"C"}"#, "settings keep their JSON string format")
            #expect(defaults.json([String: String].self, forKey: "shortcuts") == ["com.google.Chrome": "C"], "settings round-trip")
        }
    }

    @Test("legacy stored browsers decode")
    func legacyBrowsersDecode() throws {
        try withDefaults { defaults in
            defaults.set(#"["file:///Applications/A.app/"]"#, forKey: "browsers")
            #expect(defaults.json([BrowserTarget].self, forKey: "browsers")?.first?.app.lastPathComponent == "A.app")
        }
    }

    @Test("malformed stored browsers read as nil")
    func malformedBrowsersReadAsNil() throws {
        try withDefaults { defaults in
            defaults.set("[42]", forKey: "browsers")
            #expect(defaults.json([BrowserTarget].self, forKey: "browsers") == nil)
        }
    }

    @Test("missing settings read as nil")
    func missingSettingsReadAsNil() throws {
        try withDefaults { defaults in
            #expect(defaults.json([Rule].self, forKey: "missing") == nil)
        }
    }
}
