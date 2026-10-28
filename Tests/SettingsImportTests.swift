import Foundation
import Testing

/// Imported files and settings left by older builds are untrusted input.
struct SettingsImportTests {
    @Test("valid settings accepted")
    func validSettingsAccepted() {
        #expect((try? SettingsPolicy.validate(["language": "ru", "profilesEnabled": true])) != nil)
    }

    @Test("unknown language rejected on import")
    func unknownLanguageRejected() {
        #expect((try? SettingsPolicy.validate(["language": "unknown"])) == nil)
    }

    @Test("malformed browser import rejected")
    func malformedBrowsersRejected() {
        #expect((try? SettingsPolicy.validate(["browsers": "[42]"])) == nil)
    }

    @Test("integer is not boolean")
    func integerIsNotBoolean() {
        #expect((try? SettingsPolicy.validate(["profilesEnabled": 1])) == nil)
    }

    @Test("system settings excluded")
    func systemSettingsExcluded() throws {
        #expect(try SettingsPolicy.validate(["AppleLanguages": ["ru"]]).isEmpty)
    }

    @Test("numeric rule profile cannot erase rules")
    func numericRuleProfileRejected() {
        #expect((try? SettingsPolicy.validate(["rules": #"[{"app":"file:///Applications/Safari.app","regex":".*","profile":7}]"#])) == nil)
    }

    @Test("object app profile cannot erase mappings")
    func objectAppProfileRejected() {
        #expect((try? SettingsPolicy.validate(["apps": #"[{"app":"file:///Applications/Safari.app","host":"","schemeOverride":"","profile":{}}]"#])) == nil)
    }

    @Test("legacy profile settings are normalized on import")
    func legacyImportNormalized() throws {
        let imported = try SettingsPolicy.validate([
            "chromeProfiles": #"[{"directoryName":"Profile 1","displayName":"Imported","isHidden":true}]"#,
            "chromeProfilesEnabled": false,
            "shortcuts": #"{"com.google.Chrome::Profile 1":"I"}"#,
        ])

        #expect((imported["profileNames"] as? String)?.contains("Imported") == true, "legacy import aliases normalized")
        #expect((imported["shortcuts"] as? String)?.contains("com.google.Chrome#Profile 1") == true, "legacy imported shortcut normalized")
        #expect(imported["profilesEnabled"] as? Bool == false, "legacy enabled flag imported")
    }

    @Test("move shortcut validates")
    func moveShortcutValidates() {
        #expect((try? SettingsPolicy.validate(["KeyboardShortcuts_moveCurrentTab": #"{"carbonKeyCode":7,"carbonModifiers":4096}"#])) != nil)
    }

    @Test("invalid move key code rejected")
    func invalidMoveKeyCodeRejected() {
        #expect((try? SettingsPolicy.validate(["KeyboardShortcuts_moveCurrentTab": #"{"carbonKeyCode":-1,"carbonModifiers":4096}"#])) == nil)
    }

    @Test("legacy rule traversal rejected")
    func legacyRuleTraversalRejected() {
        #expect((try? SettingsPolicy.validate(["rules": #"[{"regex":".*","app":"file:///Applications/Google Chrome.app","profileDirectory":"../escape"}]"#])) == nil)
    }

    @Test("picker rule setting is importable")
    func pickerRuleSettingImportable() {
        #expect((try? SettingsPolicy.validate(["rules_showInPicker": false])) != nil)
    }

    @Test("legacy Chrome profiles migrate once")
    func legacyProfilesMigrate() throws {
        let suiteName = "LotsenTests." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let chrome = URL(fileURLWithPath: "/Applications/Google Chrome.app")
        defaults.set(#"[{"directoryName":"Profile 1","displayName":"Work","isHidden":true}]"#, forKey: "chromeProfiles")
        defaults.set(#"{"com.google.Chrome::Profile 1":"W"}"#, forKey: "shortcuts")

        SettingsPolicy.migrateLegacyProfiles(defaults: defaults, chrome: chrome)
        #expect(defaults.string(forKey: "profileNames")?.contains("Work") == true, "legacy alias preserved")
        #expect(defaults.string(forKey: "shortcuts")?.contains("com.google.Chrome#Profile 1") == true, "legacy shortcut migrated")

        let first = defaults.string(forKey: "hiddenBrowsers")
        SettingsPolicy.migrateLegacyProfiles(defaults: defaults, chrome: chrome)
        #expect(first == defaults.string(forKey: "hiddenBrowsers"), "migration idempotent")
    }

    @Test("Browserino settings copied on first launch only")
    func browserinoSettingsMigrate() throws {
        let suiteName = "LotsenTests." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let browserino: [String: Any] = ["browsers": "[]", "language": "de", "showInMenuBar": false]

        SettingsPolicy.migrateFromBrowserino(defaults: defaults, browserino: browserino)
        #expect(defaults.string(forKey: "language") == "de")
        #expect(defaults.object(forKey: "showInMenuBar") as? Bool == false)

        defaults.set("fr", forKey: "language")
        SettingsPolicy.migrateFromBrowserino(defaults: defaults, browserino: browserino)
        #expect(defaults.string(forKey: "language") == "fr", "later launches keep Lotsen's own settings")
    }

    @Test("Browserino settings never overwrite an existing setup")
    func browserinoSettingsSkippedWhenConfigured() throws {
        let suiteName = "LotsenTests." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("[]", forKey: "browsers")

        SettingsPolicy.migrateFromBrowserino(defaults: defaults, browserino: ["language": "de"])
        #expect(defaults.string(forKey: "language") == nil)
    }
}
