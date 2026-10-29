import Foundation
import Testing

struct SettingsUndoTests {
    @Test("list deletion, later edits, undo and redo preserve order and duplicates")
    func history() throws {
        let suite = "LotsenUndo-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)
        let manager = UndoManager()
        manager.groupsByEvent = false
        let first = Rule(regex: "https://example.com/*", app: URL(fileURLWithPath: "/Applications/A.app"), kind: .pattern)
        let second = Rule(regex: "https://other.com/*", app: first.app, kind: .pattern)
        settings.rules = [first, first, second]
        func change(_ rules: [Rule]) {
            manager.beginUndoGrouping()
            settings.replace(\.rules, with: rules, undoManager: manager, actionName: "Change")
            manager.endUndoGrouping()
        }
        change([first, second])
        change([second, first])
        manager.undo()
        #expect(settings.rules == [first, second], "undo later changes first")
        manager.undo()
        #expect(settings.rules == [first, first, second], "restore the exact deleted rows")
        manager.redo()
        #expect(settings.rules == [first, second])
        #expect(defaults.json([Rule].self, forKey: "rules") == settings.rules, "undo and redo persist")
        manager.removeAllActions()
        settings.replace(\.rules, with: settings.rules, undoManager: manager, actionName: "Change")
        #expect(!manager.canUndo, "no-op changes do not create undo actions")
    }
}
