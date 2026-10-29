//
//  AppSettings.swift
//  Lotsen
//

import Foundation
import SwiftUI

/// A domain mapped to the app that opens it.
struct App: Codable, Hashable {
    var host: String
    var schemeOverride: String
    var app: URL
    var profile: String?

    var target: BrowserTarget {
        BrowserTarget(app: app, profile: profile)
    }
}

/// A folder browsers are looked for in.
struct Directory: Codable, Hashable {
    var directoryPath: String
}

/// The settings stored as JSON, decoded once and kept in step with UserDefaults.
///
/// Each value is written back as it changes, and everything is read again when
/// UserDefaults changes underneath, which is how an imported settings file or a
/// migration reaches views that are already open.
@Observable
final class AppSettings {
    static let shared = AppSettings()

    var browsers: [BrowserTarget] { didSet { store(browsers, forKey: "browsers") } }
    var hiddenBrowsers: [BrowserTarget] { didSet { store(hiddenBrowsers, forKey: "hiddenBrowsers") } }
    var apps: [App] { didSet { store(apps, forKey: "apps") } }
    var rules: [Rule] { didSet { store(rules, forKey: "rules") } }
    var directories: [Directory] { didSet { store(directories, forKey: "directories") } }
    var shortcuts: [String: String] { didSet { store(shortcuts, forKey: "shortcuts") } }
    var profileNames: [String: String] { didSet { store(profileNames, forKey: "profileNames") } }
    var privateArgs: [String: String] { didSet { store(privateArgs, forKey: "privateArgs") } }

    /// Where browsers are looked for until the user adds more.
    static let defaultDirectories = [Directory(directoryPath: "/Applications")]

    @ObservationIgnored private let defaults: UserDefaults
    /// Set while values are being read back, so that doing so does not write them again.
    @ObservationIgnored private var reloading = false
    @ObservationIgnored private var observation: (any NSObjectProtocol)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        browsers = defaults.jsonKeepingUnreadable(forKey: "browsers") ?? []
        hiddenBrowsers = defaults.jsonKeepingUnreadable(forKey: "hiddenBrowsers") ?? []
        apps = defaults.jsonKeepingUnreadable(forKey: "apps") ?? []
        rules = defaults.jsonKeepingUnreadable(forKey: "rules") ?? []
        directories = defaults.jsonKeepingUnreadable(forKey: "directories") ?? Self.defaultDirectories
        shortcuts = defaults.jsonKeepingUnreadable(forKey: "shortcuts") ?? [:]
        profileNames = defaults.jsonKeepingUnreadable(forKey: "profileNames") ?? [:]
        privateArgs = defaults.jsonKeepingUnreadable(forKey: "privateArgs") ?? [:]

        observation = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: defaults,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor in self?.reload() }
        }
    }

    private func store<Value: Encodable>(_ value: Value, forKey key: String) {
        guard !reloading else {
            return
        }

        defaults.setJSON(value, forKey: key)
    }

    func replace<Value: Equatable>(
        _ keyPath: ReferenceWritableKeyPath<AppSettings, Value>, with value: Value,
        undoManager: UndoManager?, actionName: String
    ) {
        let previous = self[keyPath: keyPath]
        guard previous != value else { return }
        undoManager?.registerUndo(withTarget: self) { settings in
            settings.replace(keyPath, with: previous, undoManager: undoManager, actionName: actionName)
        }
        self[keyPath: keyPath] = value
        undoManager?.setActionName(actionName)
    }

    /// Only assigns what actually changed, so views showing the rest stay put.
    private func reload() {
        reloading = true
        defer { reloading = false }

        func update<Value: Decodable & Equatable>(_ keyPath: ReferenceWritableKeyPath<AppSettings, Value>, _ key: String, empty: Value) {
            let value = defaults.jsonKeepingUnreadable(Value.self, forKey: key) ?? empty
            if self[keyPath: keyPath] != value {
                self[keyPath: keyPath] = value
            }
        }

        update(\.browsers, "browsers", empty: [])
        update(\.hiddenBrowsers, "hiddenBrowsers", empty: [])
        update(\.apps, "apps", empty: [])
        update(\.rules, "rules", empty: [])
        update(\.directories, "directories", empty: Self.defaultDirectories)
        update(\.shortcuts, "shortcuts", empty: [:])
        update(\.profileNames, "profileNames", empty: [:])
        update(\.privateArgs, "privateArgs", empty: [:])
    }
}

/// A view's handle on one of `AppSettings`' values, used the way @AppStorage is:
/// assign to it, or pass `$name` where a binding is needed.
@propertyWrapper
struct Setting<Value>: DynamicProperty {
    private let keyPath: ReferenceWritableKeyPath<AppSettings, Value>

    init(_ keyPath: ReferenceWritableKeyPath<AppSettings, Value>) {
        self.keyPath = keyPath
    }

    var wrappedValue: Value {
        get { AppSettings.shared[keyPath: keyPath] }
        nonmutating set { AppSettings.shared[keyPath: keyPath] = newValue }
    }

    var projectedValue: Binding<Value> {
        Bindable(AppSettings.shared)[dynamicMember: keyPath]
    }
}
