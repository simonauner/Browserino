import Foundation

enum PrivateBrowsingPolicy {
    static func acceptsMultipleURLs(argument: String) -> Bool {
        // Firefox's private-window flag consumes only the next URL.
        argument != "--private-window" && argument != "-private-window"
    }

    static func argument(for identifier: String, overrides: [String: String]) -> String? {
        if let value = overrides[identifier] {
            return value.isEmpty ? nil : value
        }
        let incognito = ["com.google.Chrome", "org.chromium.Chromium", "com.brave.Browser"]
        if incognito.contains(where: { identifier == $0 || identifier.hasPrefix($0 + ".") }) {
            return "--incognito"
        }
        if identifier == "org.mozilla.firefox" || identifier == "org.mozilla.firefoxdeveloperedition" {
            return "--private-window"
        }
        if identifier == "com.microsoft.edgemac" || identifier.hasPrefix("com.microsoft.edgemac.") {
            return "--inprivate"
        }
        return nil
    }

    static func canOpen(identifier: String?, overrides: [String: String], schemeOverride: String = "") -> Bool {
        guard schemeOverride.isEmpty, let identifier else { return false }
        return argument(for: identifier, overrides: overrides) != nil
    }
}

enum LanguagePolicy {
    static let options: [(id: String, name: String)] = [
        ("en", "English"), ("ru", "Русский"), ("de", "Deutsch"), ("fr", "Français"),
        ("es", "Español"), ("pt-BR", "Português (Brasil)"), ("it", "Italiano"),
        ("ja", "日本語"), ("ko", "한국어"), ("zh-Hans", "简体中文")
    ]
    static func resolve(selection: String, preferred: [String]) -> String {
        let supported = options.map(\.id)
        if supported.contains(selection) { return selection }
        return Bundle.preferredLocalizations(from: supported, forPreferences: preferred).first ?? "en"
    }
}

enum ProfilePathPolicy {
    static func isSafeComponent(_ value: String) -> Bool {
        !value.isEmpty && value != "." && value != ".." && !value.contains("/")
            && !value.contains("\\") && !value.contains("\0")
    }
    static func contains(_ url: URL, in root: URL) -> Bool {
        func canonical(_ value: URL) -> [String] {
            var resolved = URL(fileURLWithPath: "/")
            for component in value.standardizedFileURL.pathComponents.dropFirst() {
                resolved.appendPathComponent(component)
                resolved = resolved.resolvingSymlinksInPath()
            }
            return resolved.pathComponents
        }
        let parent = canonical(root)
        let child = canonical(url)
        return child.count > parent.count && child.starts(with: parent)
    }
}

struct SourceTabIdentity: Equatable, Sendable {
    let windowID: Int
    let tabID: Int
    let url: String
}

enum TargetPolicy {
    static func isHidden(_ target: BrowserTarget, hidden: [BrowserTarget]) -> Bool {
        hidden.contains(target) || hidden.contains(BrowserTarget(app: target.app))
    }
    static func visible(_ targets: [BrowserTarget], hidden: [BrowserTarget], profilesEnabled: Bool) -> [BrowserTarget] {
        let visible = targets.filter { !isHidden($0, hidden: hidden) }
        guard !profilesEnabled else { return visible }
        var seen = Set<URL>()
        return visible.compactMap { seen.insert($0.app).inserted ? BrowserTarget(app: $0.app) : nil }
    }
    static func preserveHidden(oldTargets: [BrowserTarget], newTargets: [BrowserTarget], hidden: [BrowserTarget]) -> [BrowserTarget] {
        var result = hidden
        for target in newTargets where target.profile == nil {
            let old = oldTargets.filter { $0.app == target.app }
            if !old.isEmpty, old.allSatisfy({ isHidden($0, hidden: hidden) }), !result.contains(target) { result.append(target) }
        }
        return result
    }
    /// A shortcut recorded on a browser's own row moves to its first profile without
    /// one once only its profiles are listed. Left on the browser, it would show on
    /// no row in Settings while the picker had nothing to put it on. An app row
    /// that still opens the browser itself keeps it.
    static func moveShortcutsToProfiles(_ targets: [BrowserTarget], shortcuts: [String: String], keeping: [BrowserTarget], bundleIdentifier: (URL) -> String?) -> [String: String] {
        var result = shortcuts
        for target in targets where target.profile != nil {
            let browser = BrowserTarget(app: target.app)
            guard !targets.contains(browser), !keeping.contains(browser), let identifier = bundleIdentifier(target.app),
                  let key = result[identifier], result[target.shortcutKey(bundleIdentifier: identifier)] == nil else { continue }
            result[identifier] = nil
            result[target.shortcutKey(bundleIdentifier: identifier)] = key
        }
        return result
    }
    /// Keeps the order the user arranged, and drops anything newly discovered next
    /// to its own browser rather than at the end.
    static func merge(
        discovered: [BrowserTarget],
        into oldBrowsers: [BrowserTarget]
    ) -> [BrowserTarget] {
        let discoveredTargets = Set(discovered)

        var merged: [BrowserTarget] = []
        var placed: Set<BrowserTarget> = []

        for old in oldBrowsers {
            if discoveredTargets.contains(old) {
                if placed.insert(old).inserted {
                    merged.append(old)
                }
            } else {
                // This exact entry is gone, but the same browser may now be
                // represented differently — profiles replacing the plain row on
                // first run. Those belong where the user had put the browser, not
                // at the bottom of the list.
                for target in discovered
                where target.app == old.app && placed.insert(target).inserted {
                    merged.append(target)
                }
            }
        }

        for target in discovered where !placed.contains(target) {
            if let last = merged.lastIndex(where: { $0.app == target.app }) {
                merged.insert(target, at: last + 1)
            } else {
                merged.append(target)
            }

            placed.insert(target)
        }

        return merged
    }
    static func toggle(_ target: BrowserTarget, targets: [BrowserTarget], hidden: [BrowserTarget]) -> [BrowserTarget] {
        var result = hidden
        if target.profile == nil {
            let appTargets = targets.filter { $0.app == target.app }
            if hidden.contains(target) || (!appTargets.isEmpty && appTargets.allSatisfy({ isHidden($0, hidden: hidden) })) {
                result.removeAll { $0.app == target.app }
            } else { result.append(target) }
        } else {
            let base = BrowserTarget(app: target.app)
            if result.contains(base) {
                result.removeAll { $0 == base }
                for row in targets where row.app == target.app && !result.contains(row) { result.append(row) }
            }
            if let index = result.firstIndex(of: target) { result.remove(at: index) }
            else { result.append(target) }
        }
        return result
    }
}
